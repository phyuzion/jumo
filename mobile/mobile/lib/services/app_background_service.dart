// lib/services/app_background_service.dart

import 'dart:async';
import 'dart:developer';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:mobile/graphql/notification_api.dart';
import 'package:mobile/services/local_notification_service.dart';
import 'package:mobile/controllers/contacts_controller.dart';
import 'package:mobile/graphql/log_api.dart';
import 'package:hive_ce/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:mobile/models/blocked_history.dart';

@pragma('vm:entry-point')
Future<void> onStart(ServiceInstance service) async {
  // ***** 1. Hive 초기화 및 Box 열기 먼저 수행 *****
  bool hiveInitialized = false;
  try {
    final appDocumentDir = await getApplicationDocumentsDirectory();
    Hive.init(appDocumentDir.path);
    if (!Hive.isAdapterRegistered(BlockedHistoryAdapter().typeId)) {
      Hive.registerAdapter(BlockedHistoryAdapter());
    }
    // 모든 Box 열기 시도
    if (!Hive.isBoxOpen('settings')) await Hive.openBox('settings');
    if (!Hive.isBoxOpen('blocked_history'))
      await Hive.openBox<BlockedHistory>('blocked_history');
    if (!Hive.isBoxOpen('call_logs')) await Hive.openBox('call_logs');
    if (!Hive.isBoxOpen('sms_logs')) await Hive.openBox('sms_logs');
    if (!Hive.isBoxOpen('last_sync_state'))
      await Hive.openBox('last_sync_state');
    if (!Hive.isBoxOpen('notifications')) await Hive.openBox('notifications');
    if (!Hive.isBoxOpen('auth')) await Hive.openBox('auth');
    if (!Hive.isBoxOpen('display_noti_ids'))
      await Hive.openBox('display_noti_ids');
    if (!Hive.isBoxOpen('blocked_numbers'))
      await Hive.openBox('blocked_numbers');
    hiveInitialized = true; // 초기화 성공 플래그
    log('[BackgroundService] Hive initialized and boxes opened.');
  } catch (e) {
    log('[BackgroundService] Error initializing Hive in background: $e');
    // Hive 초기화 실패 시 서비스 중단 또는 다른 처리 필요
    // return; // 필요 시 여기서 리턴
  }

  // Hive 초기화 실패 시 아래 로직 실행하지 않도록 처리 (선택적)
  // if (!hiveInitialized) return;

  // ***** 2. Hive 초기화 완료 후 타이머 및 리스너 설정 *****
  log('[BackgroundService] Setting up periodic timers and event listeners...');

  // --- 주기적 작업들 ---
  Timer.periodic(const Duration(minutes: 1), (timer) async {
    log('[BackgroundService] Periodic task (1 min) running...');
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

  // 연락처 동기화 주기 작업 유지
  Timer.periodic(const Duration(minutes: 10), (timer) async {
    // Hive 초기화 완료 확인 (선택적 강화)
    if (!hiveInitialized) {
      log(
        '[BackgroundService] Hive not initialized, skipping periodic contact sync.',
      );
      return;
    }
    log('[BackgroundService] Starting periodic contact sync...');
    await performContactBackgroundSync(); // 이제 Box가 열려 있음
  });

  // --- 이벤트 기반 작업들 --- (모든 리스너 설정은 Hive 초기화 후)
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

  service.on('startContactSyncNow').listen((event) async {
    log('[BackgroundService] Received request for immediate contact sync.');
    if (!hiveInitialized) {
      log(
        '[BackgroundService] Hive not initialized, cannot perform immediate sync.',
      );
      return;
    }
    await performContactBackgroundSync();
  });

  service.on('uploadCallLogs').listen((event) async {
    // Box 열림 확인 추가
    const boxName = 'call_logs';
    if (!Hive.isBoxOpen(boxName)) {
      log('[BackgroundService] Box \'$boxName\' not open for uploadCallLogs.');
      return;
    }

    if (event == null || event['logs'] == null) {
      log('[BackgroundService] Invalid uploadCallLogs event received.');
      return;
    }
    final logsToUpload = List<Map<String, dynamic>>.from(event['logs']);
    if (logsToUpload.isNotEmpty) {
      log('[BackgroundService] Received ${logsToUpload.length} call logs...');
      try {
        await LogApi.updateCallLog(logsToUpload);
        log('[BackgroundService] Uploaded call logs.');
      } catch (e) {
        log('[BackgroundService] Failed to upload call logs: $e');
      }
    }
  });

  service.on('uploadSmsLogs').listen((event) async {
    // Box 열림 확인 추가
    const boxName = 'sms_logs';
    if (!Hive.isBoxOpen(boxName)) {
      log('[BackgroundService] Box \'$boxName\' not open for uploadSmsLogs.');
      return;
    }

    if (event == null || event['sms'] == null) {
      log('[BackgroundService] Invalid uploadSmsLogs event received.');
      return;
    }
    final smsToUpload = List<Map<String, dynamic>>.from(event['sms']);
    if (smsToUpload.isNotEmpty) {
      log('[BackgroundService] Received ${smsToUpload.length} sms logs...');
      try {
        await LogApi.updateSMSLog(smsToUpload);
        log('[BackgroundService] Uploaded sms logs.');
      } catch (e) {
        log('[BackgroundService] Failed to upload sms logs: $e');
      }
    }
  });

  service.on('stopService').listen((event) async {
    log('[BackgroundService] stopService event received');
    callTimer?.cancel();
    // TODO: 주기적 타이머들도 cancel 필요
    service.stopSelf();
    await LocalNotificationService.cancelNotification(ONGOING_CALL_NOTI_ID);
  });

  log('[BackgroundService] Setup complete.');
}
