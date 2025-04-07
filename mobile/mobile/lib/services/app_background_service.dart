// lib/services/app_background_service.dart

import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:mobile/graphql/notification_api.dart';
import 'package:mobile/services/local_notification_service.dart';
import 'package:mobile/controllers/contacts_controller.dart';
import 'package:mobile/graphql/log_api.dart';
import 'package:hive_ce/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:mobile/models/blocked_history.dart';
import 'package:call_e_log/call_log.dart';
import 'package:flutter_sms_intellect/flutter_sms_intellect.dart';
import 'package:mobile/graphql/search_api.dart';
import 'package:mobile/graphql/block_api.dart';
import 'package:mobile/utils/constants.dart';
import 'package:flutter/foundation.dart';
import 'package:mobile/controllers/call_log_controller.dart';
import 'package:mobile/controllers/sms_controller.dart';

@pragma('vm:entry-point')
Future<void> onStart(ServiceInstance service) async {
  // ***** 1. Hive 초기화 및 Box 열기 *****
  bool hiveInitialized = false;
  try {
    final appDocumentDir = await getApplicationDocumentsDirectory();
    Hive.init(appDocumentDir.path);
    if (!Hive.isAdapterRegistered(BlockedHistoryAdapter().typeId)) {
      Hive.registerAdapter(BlockedHistoryAdapter());
    }
    await Hive.openBox('settings');
    await Hive.openBox<BlockedHistory>('blocked_history');
    await Hive.openBox('call_logs');
    await Hive.openBox('sms_logs');
    await Hive.openBox('last_sync_state');
    await Hive.openBox('notifications');
    await Hive.openBox('auth');
    await Hive.openBox('display_noti_ids');
    await Hive.openBox('blocked_numbers');
    hiveInitialized = true;
    log('[BackgroundService] Hive initialized and boxes opened.');
  } catch (e) {
    log('[BackgroundService] Error initializing Hive in background: $e');
    service.stopSelf();
    return;
  }

  // Hive 초기화 실패 시 종료
  if (!hiveInitialized) return;

  log('[BackgroundService] Setting up periodic timers and event listeners...');

  // --- 주기적 작업들 ---
  Timer? notificationTimer;
  Timer? contactSyncTimer;
  Timer? blockSyncTimer;
  Timer? smsSyncTimer;

  // 알림 확인 타이머 (10분으로 변경)
  notificationTimer = Timer.periodic(const Duration(minutes: 10), (
    timer,
  ) async {
    log(
      '[BackgroundService] Periodic task (Notifications - 10 min) running...',
    );
    // 서버 알림 확인 로직 유지
    try {
      final notiList = await NotificationApi.getNotifications();
      if (notiList.isEmpty) return;
      service.invoke('removeExpiredNotifications');
      for (final n in notiList) {
        final sid = (n['id'] ?? '').toString();
        if (sid.isEmpty) continue;
        service.invoke('saveNotification', {
          'id': sid,
          'title': n['title'] as String? ?? 'No Title',
          'message': n['message'] as String? ?? '...',
          'validUntil': n['validUntil'],
        });
      }
    } catch (e) {
      log('[BackgroundService] Error fetching notifications: $e');
    }
  });

  // 연락처 동기화 타이머 (10분 유지)
  contactSyncTimer = Timer.periodic(const Duration(minutes: 10), (timer) async {
    log('[BackgroundService] Starting periodic contact sync...');
    await performContactBackgroundSync();
  });

  // 차단 목록 동기화 타이머 (1시간 유지)
  blockSyncTimer = Timer.periodic(const Duration(hours: 1), (timer) async {
    log(
      '[BackgroundService] Starting periodic blocked/danger/bomb numbers sync...',
    );
    await syncBlockedLists();
  });

  // SMS 동기화 타이머 (15분 유지)
  smsSyncTimer = Timer.periodic(const Duration(minutes: 15), (timer) async {
    log('[BackgroundService] Starting periodic SMS sync...');
    await _refreshAndUploadSms(); // 읽기+저장+업로드 헬퍼 호출
  });

  // --- 이벤트 기반 작업들 ---
  String? ongoingNumber;
  String? ongoingName;
  int ongoingSeconds = 0;
  Timer? callTimer;
  const ONGOING_CALL_NOTI_ID = 9999;

  service.on('startCallTimer').listen((event) async {
    final phoneNumber = event?['phoneNumber'] as String? ?? '';
    final callerName = event?['callerName'] as String? ?? '';

    log('[BackgroundService] startCallTimer => $phoneNumber');

    ongoingNumber = phoneNumber;
    ongoingName = callerName.isNotEmpty ? callerName : '';
    ongoingSeconds = 0;

    await LocalNotificationService.showOngoingCallNotification(
      id: ONGOING_CALL_NOTI_ID,
      callerName: ongoingName ?? '',
      phoneNumber: ongoingNumber ?? '',
    );
    callTimer?.cancel();
    callTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      ongoingSeconds++;

      service.invoke('updateCallUI', {
        'elapsed': ongoingSeconds,
        'phoneNumber': ongoingNumber,
      });
    });
  });

  service.on('stopCallTimer').listen((event) async {
    log('[BackgroundService] stopCallTimer');
    callTimer?.cancel();
    callTimer = null;
    await LocalNotificationService.cancelNotification(ONGOING_CALL_NOTI_ID);
  });

  // 즉시 연락처 동기화 요청
  service.on('startContactSyncNow').listen((event) async {
    log('[BackgroundService] Received request for immediate contact sync.');
    await performContactBackgroundSync();
  });

  // 통화 기록 업로드 요청 (이벤트 이름 변경)
  service.on('uploadCallLogsNow').listen((event) async {
    log('[BackgroundService] Received uploadCallLogsNow request.');
    await _uploadCallLogs(); // 업로드만 수행하는 헬퍼 호출
  });

  service.on('stopService').listen((event) async {
    log('[BackgroundService] stopService event received');
    callTimer?.cancel();
    notificationTimer?.cancel();
    contactSyncTimer?.cancel();
    blockSyncTimer?.cancel();
    smsSyncTimer?.cancel();
    service.stopSelf();
    await LocalNotificationService.cancelNotification(ONGOING_CALL_NOTI_ID);
  });

  // ***** 3. 서비스 시작 시 초기 동기화 수행 *****
  log('[BackgroundService] Performing initial sync tasks...');
  await syncBlockedLists();

  log('[BackgroundService] Setup complete.');
}

// --- Helper Functions for Background Tasks (Top-level) ---

// 통화 기록 업로드만 수행하는 함수
Future<void> _uploadCallLogs() async {
  log('[BackgroundService] Executing _uploadCallLogs...');
  try {
    final callLogBox = Hive.box('call_logs');
    if (!callLogBox.isOpen) {
      log('[BG] call_logs box closed.');
      return;
    }

    // Hive에서 로그 읽기 (JSON 디코딩)
    final logString = callLogBox.get('logs', defaultValue: '[]') as String;
    final List<Map<String, dynamic>> logsToUpload;
    try {
      final decodedList = jsonDecode(logString) as List;
      logsToUpload = decodedList.cast<Map<String, dynamic>>().toList();
    } catch (e) {
      log('[BackgroundService] Error decoding call logs for upload: $e');
      return;
    }

    if (logsToUpload.isNotEmpty) {
      // 서버 전송용 데이터 준비
      final logsForServer = CallLogController.prepareLogsForServer(
        logsToUpload,
      );
      if (logsForServer.isNotEmpty) {
        await LogApi.updateCallLog(logsForServer);
        log('[BackgroundService] Uploaded call logs.');
        // TODO: 업로드 성공 시 Hive 데이터 삭제 또는 상태 변경 고려
      }
    } else {
      log('[BackgroundService] No call logs in Hive to upload.');
    }
  } catch (e) {
    log('[BackgroundService] Error handling _uploadCallLogs: $e');
  }
}

// SMS 새로고침 및 업로드 함수 (주기적 타이머가 호출)
Future<void> _refreshAndUploadSms() async {
  log('[BackgroundService] Executing _refreshAndUploadSms...');
  try {
    final smsLogBox = Hive.box('sms_logs');
    if (!smsLogBox.isOpen) {
      log('[BG] sms_logs box closed.');
      return;
    }

    final messages = await SmsInbox.getAllSms(count: 10);
    final smsList = <Map<String, dynamic>>[];
    // ... (파싱 로직)
    for (final msg in messages) {
      /* ... */
    }

    await smsLogBox.put('logs', jsonEncode(smsList));
    log('[BackgroundService] Saved ${smsList.length} sms logs locally.');

    // 서버 업로드
    final smsForServer = SmsController.prepareSmsForServer(smsList);
    if (smsForServer.isNotEmpty) {
      // TODO: 업로드 실패 시 재시도 로직 추가 필요
      await LogApi.updateSMSLog(smsForServer);
      log('[BackgroundService] Uploaded sms logs after refresh.');
    }
  } catch (e) {
    log('[BackgroundService] Error handling _refreshAndUploadSms: $e');
    // TODO: 권한 오류 등 처리
  }
}

// 차단 목록 관련 동기화 함수 (위험/콜폭 번호만 처리하도록 수정)
Future<void> syncBlockedLists() async {
  log('[BackgroundService] Executing periodic sync for Danger/Bomb lists...');
  // Box 직접 접근
  final settingsBox = Hive.box('settings');
  // final blockedNumbersBox = Hive.box('blocked_numbers'); // 사용자 목록 동기화는 여기서 안 함
  // final dangerNumbersBox = Hive.box('danger_numbers'); // 사용 시 열기 확인 필요
  // final bombNumbersBox = Hive.box('bomb_numbers'); // 사용 시 열기 확인 필요

  // if (!settingsBox.isOpen) { // Box 열림 확인
  //    log('[BackgroundService] Settings box not open for syncBlockedLists.');
  //    return;
  // }
  // 안전을 위해 isBoxOpen은 유지하거나, onStart에서 열림 보장 가정
  if (!settingsBox.isOpen) {
    log(
      '[BackgroundService] Settings box is not open. Aborting syncBlockedLists.',
    );
    return;
  }

  try {
    // 1. 사용자 차단 목록 동기화 제거
    // final serverNumbers = await BlockApi.getBlockedNumbers();
    // ... (Hive 저장 로직 제거)

    // 2. 위험 번호 업데이트 (유지)
    final isAutoBlockDanger = settingsBox.get(
      'isAutoBlockDanger',
      defaultValue: false,
    );
    if (isAutoBlockDanger) {
      log('[BackgroundService] Syncing danger numbers...');
      final dangerNumbers = await SearchApi.getPhoneNumbersByType(99);
      // TODO: 위험 번호 Hive 저장 (별도 Box 권장: 'danger_numbers')
      // 예: final dangerBox = await Hive.openBox('danger_numbers');
      //     await dangerBox.put('list', dangerNumbers.map((n)=>n.phoneNumber).toList());
      log('[BackgroundService] Synced danger numbers: ${dangerNumbers.length}');
    }

    // 3. 콜폭 번호 업데이트 (유지)
    final isBombBlocked = settingsBox.get(
      'isBombCallsBlocked',
      defaultValue: false,
    );
    final bombCount = settingsBox.get('bombCallsCount', defaultValue: 0);
    if (isBombBlocked && bombCount > 0) {
      log(
        '[BackgroundService] Syncing bomb call numbers (count: $bombCount)...',
      );
      final bombNumbers = await BlockApi.getBlockNumbers(bombCount);
      // TODO: 콜폭 번호 Hive 저장 (별도 Box 권장: 'bomb_numbers')
      // 예: final bombBox = await Hive.openBox('bomb_numbers');
      //     await bombBox.put('list', bombNumbers.map((n)=>n['phoneNumber'] as String).toList());
      log(
        '[BackgroundService] Synced bomb call numbers: ${bombNumbers.length}',
      );
    }
  } catch (e) {
    log('[BackgroundService] Error during syncBlockedLists (danger/bomb): $e');
  }
}
