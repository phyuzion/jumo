// lib/services/app_background_service.dart

import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:ui'; // DartPluginRegistrant 사용 위해 추가
import 'dart:isolate'; // <<< Isolate 사용 위해 추가 >>>
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart'; // AndroidServiceInstance 사용 위해 추가
import 'package:flutter_local_notifications/flutter_local_notifications.dart'; // <<< Local Notifications 임포트 추가
import 'package:mobile/graphql/notification_api.dart';
import 'package:mobile/controllers/contacts_controller.dart';
import 'package:mobile/graphql/log_api.dart';
import 'package:hive_ce/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:mobile/models/blocked_history.dart';
import 'package:flutter_sms_intellect/flutter_sms_intellect.dart';
import 'package:mobile/graphql/search_api.dart';
import 'package:mobile/graphql/block_api.dart';
import 'package:mobile/utils/constants.dart';
import 'package:mobile/controllers/sms_controller.dart';
import 'package:mobile/controllers/app_controller.dart';
import 'package:flutter_broadcasts_4m/flutter_broadcasts.dart';
//import 'package:system_alert_window/system_alert_window.dart';

const int CALL_STATUS_NOTIFICATION_ID = 1111; // 통화 상태 알림 전용 ID
const String FOREGROUND_SERVICE_CHANNEL_ID = 'jumo_foreground_service_channel';

@pragma('vm:entry-point')
Future<void> onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  log(
    '[BackgroundService][onStart] Service instance started. Isolate: ${Isolate.current.hashCode}',
  );

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Timer? callTimer;
  int ongoingSeconds = 0;
  String _currentNumberForTimer = "";
  String _currentCallerNameForTimer = "";
  SmsController _smsController = SmsController();
  // <<< Hive 초기화 (기존 코드 유지) >>>
  bool hiveInitialized = false;
  Box? settingsBox;
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
    await Hive.openBox<List<String>>('danger_numbers');
    await Hive.openBox<List<String>>('bomb_numbers');
    hiveInitialized = true;
    log('[BackgroundService][onStart] Hive initialized successfully.');
  } catch (e) {
    log('[BackgroundService][onStart] Error initializing Hive: $e');
    service.stopSelf();
    return;
  }

  if (!hiveInitialized) {
    // settingsBox null check 제거 (어차피 여기서 사용 안 함)
    log(
      '[BackgroundService][onStart] Hive initialization failed. Stopping service.',
    );
    service.stopSelf();
    return;
  }

  // <<< 기본 전화 앱 여부 확인 로직 삭제 (아래 Helper 함수 사용) >>>
  // bool isDefaultDialer = false;
  // try { ... } catch (e) { ... }

  // --- Helper Function ---
  // 메인 Isolate에 isDefaultDialer 상태를 요청하고 응답을 기다리는 함수
  Future<bool> _fetchIsDefaultDialerFromMain() async {
    final completer = Completer<bool>();
    StreamSubscription? subscription;

    // 응답 리스너 설정 (한 번만 수신)
    subscription = service.on('respondDefaultDialerStatus').listen((event) {
      final bool isDefault = event?['isDefault'] ?? false;
      log(
        '[BackgroundService] Received respondDefaultDialerStatus: $isDefault',
      );
      if (!completer.isCompleted) {
        completer.complete(isDefault);
      }
      subscription?.cancel(); // 리스너 정리
    });

    // 타임아웃 추가 (메인 Isolate 응답이 없을 경우 대비)
    Future.delayed(const Duration(seconds: 3), () {
      if (!completer.isCompleted) {
        log(
          '[BackgroundService] Timeout waiting for respondDefaultDialerStatus. Assuming false.',
        );
        completer.complete(false); // 타임아웃 시 기본값 false
        subscription?.cancel();
      }
    });

    // 메인 Isolate에 요청 보내기
    log('[BackgroundService] Sending requestDefaultDialerStatus to main.');
    service.invoke('requestDefaultDialerStatus');

    return completer.future;
  }
  // --- End Helper Function ---

  // <<< 시간 포맷 함수 정의 먼저 >>>
  String _formatDurationBackground(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return "$minutes:$secs";
  }

  // <<< 타이머 중지 함수 정의 먼저 >>>
  void _stopCallTimerBackground() {
    if (callTimer?.isActive ?? false) {
      callTimer!.cancel();
      log('[BackgroundService] Call timer stopped.');
    }
    callTimer = null;
    ongoingSeconds = 0;
  }

  // <<< 타이머 시작 함수 정의 >>>
  void _startCallTimerBackground() {
    _stopCallTimerBackground();
    ongoingSeconds = 0;
    callTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      ongoingSeconds++;
      if (service is AndroidServiceInstance) {
        if (await service.isForegroundService()) {
          // <<< 저장된 최신 정보 사용 >>>
          String title =
              '통화중... (${_formatDurationBackground(ongoingSeconds)})';
          String content =
              '$_currentCallerNameForTimer ($_currentNumberForTimer)';
          String payload = 'active:$_currentNumberForTimer';

          // <<< 알림 업데이트 show() 호출 수정 >>>
          flutterLocalNotificationsPlugin.show(
            FOREGROUND_SERVICE_NOTIFICATION_ID,
            title,
            content,
            const NotificationDetails(
              android: AndroidNotificationDetails(
                FOREGROUND_SERVICE_CHANNEL_ID,
                'KOLPON 서비스 상태',
                icon: 'ic_bg_service_small',
                ongoing: true,
                autoCancel: false,
                importance: Importance.low,
                priority: Priority.low,
                playSound: false,
                enableVibration: false,
                onlyAlertOnce: true,
              ),
            ),
            payload: payload,
          );

          service.invoke('updateUiCallState', {
            'state': 'active',
            'number': _currentNumberForTimer,
            'callerName': _currentCallerNameForTimer,
            'connected': true,
            'duration': ongoingSeconds,
            'reason': '',
          });
        }
      }
    });
    log('[BackgroundService] Call timer started.');
  }

  // <<< 로그 추가: Hive 초기화 시도 전 >>>
  log('[BackgroundService][onStart] Attempting to initialize Hive...');

  // Hive 초기화 실패 시 종료
  if (!hiveInitialized) return;

  // <<< 서비스 시작 시 초기 알림 설정 >>>
  if (service is AndroidServiceInstance) {
    if (await service.isForegroundService()) {
      log('[BackgroundService] Setting initial foreground notification.');
      flutterLocalNotificationsPlugin.show(
        FOREGROUND_SERVICE_NOTIFICATION_ID,
        'KOLPON 감지 중', // 초기 제목
        '실시간 통화 감지 중', // 초기 내용
        const NotificationDetails(
          android: AndroidNotificationDetails(
            FOREGROUND_SERVICE_CHANNEL_ID,
            'KOLPON 서비스 상태',
            icon: 'ic_bg_service_small',
            ongoing: true,
            autoCancel: false,
            importance: Importance.low,
            priority: Priority.low,
            playSound: false,
            enableVibration: false,
            onlyAlertOnce: true,
          ),
        ),
        payload: 'idle', // 초기 페이로드
      );
    }
  }
  // <<< 초기 알림 설정 끝 >>>

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

  // 연락처 동기화 타이머 (1일)
  contactSyncTimer = Timer.periodic(const Duration(days: 1), (timer) async {
    log('[BackgroundService] Starting periodic contact sync...');
    await performContactBackgroundSync();
  });

  // 차단 목록 동기화 타이머 (1시간 주기 - 호출 확인)
  blockSyncTimer = Timer.periodic(const Duration(hours: 1), (timer) async {
    log(
      '[BackgroundService] Starting periodic blocked/danger/bomb numbers sync...',
    );
    await syncBlockedLists(); // <<< 주기적으로 헬퍼 호출 확인
  });

  // SMS 동기화 타이머 (15분 유지)
  smsSyncTimer = Timer.periodic(const Duration(minutes: 10), (timer) async {
    log('[BackgroundService] Starting periodic SMS sync...');
    _smsController.refreshSms(); // 읽기+저장+업로드 헬퍼 호출
  });

  // --- 이벤트 기반 작업들 ---

  // <<< 통화 상태 변경 리스너 (수정됨) >>>
  service.on('callStateChanged').listen((event) async {
    log(
      '[BackgroundService][on:callStateChanged] Received callStateChanged event: $event',
    );

    if (event == null) {
      log(
        '[BackgroundService][on:callStateChanged] Received null event. Skipping.',
      );
      return;
    }
    // <<< 상태 변수 업데이트 로그 추가 >>>
    _currentNumberForTimer = event['number'] ?? _currentNumberForTimer;
    _currentCallerNameForTimer =
        event['callerName'] as String? ?? _currentCallerNameForTimer;
    log(
      '[BackgroundService][on:callStateChanged] Updated timer info: Number=$_currentNumberForTimer, Name=$_currentCallerNameForTimer',
    );

    final state = event['state'] as String?;
    final number = event['number'] as String? ?? ''; // null 대신 빈 문자열
    final callerName =
        event['callerName'] as String? ?? '알 수 없음'; // null 대신 기본값
    final isConnected = event['connected'] as bool? ?? false;
    final reason = event['reason'] as String? ?? '';

    log(
      '[BackgroundService] Received callStateChanged: state=$state, num=$number, name=$callerName, connected=$isConnected, reason=$reason',
    );

    // <<< 타이머 로직 호출 >>>
    if (state == 'active' && isConnected == true) {
      _startCallTimerBackground();
    } else {
      _stopCallTimerBackground();
    }

    if (state != null) {
      String title = 'KOLPON 감지 중';
      String content = '실시간 통화 감지 중';
      String payload = 'idle';

      switch (state) {
        case 'incoming':
          title = '전화 수신 중';
          content = '발신: $callerName ($number)';
          payload = 'incoming:$number';
          break;
        case 'active':
          // <<< 타이머 시작 시점에는 duration이 0일 수 있음 >>>
          title = '통화 중';
          content =
              '$callerName ($number) (${_formatDurationBackground(ongoingSeconds)})'; // 타이머 값 반영
          payload = 'active:$number';
          break;
        case 'ended':
          title = 'KOLPON 감지 중'; // 종료 시 기본으로 복원
          content = '실시간 통화 감지 중';
          payload = 'idle';
          break;
        default:
          log('[BackgroundService] Unknown call state received: $state');
          return;
      }

      // 포그라운드 알림 업데이트 (타이머와 별개로 상태 변경 시에도 업데이트)
      if (service is AndroidServiceInstance) {
        if (await service.isForegroundService()) {
          log(
            '[BackgroundService] Updating foreground notification (ID: $FOREGROUND_SERVICE_NOTIFICATION_ID): Title=$title, Content=$content, Payload=$payload',
          );
          flutterLocalNotificationsPlugin.show(
            FOREGROUND_SERVICE_NOTIFICATION_ID,
            title,
            content,
            const NotificationDetails(
              android: AndroidNotificationDetails(
                FOREGROUND_SERVICE_CHANNEL_ID,
                'KOLPON 서비스 상태',
                icon: 'ic_bg_service_small',
                ongoing: true,
                autoCancel: false,
                importance: Importance.low,
                priority: Priority.low,
                playSound: false,
                enableVibration: false,
                onlyAlertOnce: true,
              ),
            ),
            payload: payload,
          );
        }
      }

      // <<< UI 업데이트 invoke 전 로그 >>>
      log(
        '[BackgroundService][on:callStateChanged] Preparing to invoke UI update (updateUiCallState).',
      );
      // UI 스레드로 상태 업데이트 이벤트 보내기 (타이머 값 포함)
      log('[BackgroundService] Invoking UI update: updateUiCallState');
      service.invoke('updateUiCallState', {
        'state': state,
        'number': number,
        'callerName': callerName,
        'connected': isConnected,
        'duration': ongoingSeconds, // <<< 타이머 값 전달
        'reason': reason,
      });
    }
  });

  // 즉시 연락처 동기화 요청
  service.on('startContactSyncNow').listen((event) async {
    log(
      '[BackgroundService][on:startContactSyncNow] Received immediate contact sync request.',
    );
    await performContactBackgroundSync();
  });

  // 즉시 차단 목록 동기화 요청
  service.on('syncBlockedListsNow').listen((event) async {
    log(
      '[BackgroundService][on:syncBlockedListsNow] Received syncBlockedListsNow request.',
    );
    await syncBlockedLists();
  });

  service.on('stopService').listen((event) async {
    log('[BackgroundService][on:stopService] Received stopService event.');
    _stopCallTimerBackground();
    notificationTimer?.cancel();
    contactSyncTimer?.cancel();
    blockSyncTimer?.cancel();
    smsSyncTimer?.cancel();
    service.stopSelf();
  });

  log('[BackgroundService] Setting up BroadcastReceiver for PHONE_STATE...');

  // ***** 전화 상태 BroadcastReceiver 설정 *****
  try {
    const String phoneStateAction = "android.intent.action.PHONE_STATE";
    final BroadcastReceiver receiver = BroadcastReceiver(
      names: <String>[phoneStateAction],
    );

    receiver.messages.listen((message) async {
      log(
        '[BackgroundService][BroadcastReceiver] Received broadcast message for $phoneStateAction:',
      );
      final Map<String, dynamic>? intentExtras = message?.data;
      log(
        '[BackgroundService][BroadcastReceiver] Message content (Intent Extras): $intentExtras',
      );

      if (intentExtras != null) {
        final String? state =
            intentExtras['state']; // TelephonyManager.EXTRA_STATE
        final String? incomingNumber =
            intentExtras['incoming_number']; // TelephonyManager.EXTRA_INCOMING_NUMBER
        log(
          '[BackgroundService][BroadcastReceiver] Parsed state: $state, incomingNumber: $incomingNumber',
        );

        // <<< 여기서 실시간으로 isDefaultDialer 상태 확인 >>>
        bool isDefaultDialer = await _fetchIsDefaultDialerFromMain();
        log(
          '[BackgroundService][BroadcastReceiver] Fetched isDefaultDialer status: $isDefaultDialer',
        );

        /* overlay removed
        // 이제 isDefaultDialer 값을 사용
        if (!isDefaultDialer) {
          if (state == 'RINGING' &&
              incomingNumber != null &&
              incomingNumber.isNotEmpty) {
            final ringingData = {
              'type': 'ringing',
              'phoneNumber': incomingNumber,
            };
            await SystemAlertWindow.sendMessageToOverlay(ringingData);

            SearchResultModel? searchResultModel;
            try {
              final phoneData = await SearchRecordsController.searchPhone(
                incomingNumber,
              );
              final todayRecords =
                  await SearchRecordsController.searchTodayRecord(
                    incomingNumber,
                  );
              searchResultModel = SearchResultModel(
                phoneNumberModel: phoneData,
                todayRecords: todayRecords,
              );
            } catch (e, stackTrace) {
              log(
                '[BackgroundService][BroadcastReceiver] Error searching records: $e\n$stackTrace',
              );
              searchResultModel = null;
            }

            final resultData = {
              'type': 'result',
              'phoneNumber': incomingNumber,
              'searchResult': searchResultModel?.toJson(),
            };
            try {
              await SystemAlertWindow.sendMessageToOverlay(resultData);
              log(
                '[BackgroundService][BroadcastReceiver] Sent result state via sendMessageToOverlay.',
              );
            } catch (e) {
              log(
                '[BackgroundService][BroadcastReceiver] Error sending result data: $e',
              );
            }
          } else if (state == 'IDLE') {
            log(
              '[BackgroundService][BroadcastReceiver] IDLE state detected. Closing overlay...',
            );
            Future.delayed(const Duration(seconds: 10), () async {
              try {
                await SystemAlertWindow.closeSystemWindow(
                  prefMode: SystemWindowPrefMode.OVERLAY,
                );
              } catch (e) {
                log(
                  '[BackgroundService][BroadcastReceiver] Error closing overlay: $e',
                );
              }
            });
          }
        } else {
          log(
            '[BackgroundService][BroadcastReceiver] Default dialer is active. Skipping overlay logic.',
          );
        }
        */
      }
    });

    await receiver.start();
  } catch (e) {
    log(
      '[BackgroundService][onStart] Error setting up or starting BroadcastReceiver: $e',
    );
  }

  await performInitialBackgroundTasks();
  log(
    '[BackgroundService][onStart] Initial background tasks completed. Service is ready.',
  );
}

Future<void> performInitialBackgroundTasks() async {
  // <<< 로그 추가 >>>
  log(
    '[BackgroundService][performInitialBackgroundTasks] Starting initial tasks...',
  );
  await Future.delayed(const Duration(seconds: 5)); // 예시 딜레이
  log(
    '[BackgroundService][performInitialBackgroundTasks] Initial tasks finished.',
  );
}

// 차단 목록 관련 동기화 함수 (로직 강화)
Future<void> syncBlockedLists() async {
  log('[BackgroundService] Executing syncBlockedLists (User, Danger, Bomb)...');
  const settingsBoxName = 'settings';
  const blockedNumbersBoxName = 'blocked_numbers';
  const dangerNumbersBoxName = 'danger_numbers';
  const bombNumbersBoxName = 'bomb_numbers';

  // 필요한 Box 열려있는지 확인
  if (!Hive.isBoxOpen(settingsBoxName) ||
      !Hive.isBoxOpen(blockedNumbersBoxName) ||
      !Hive.isBoxOpen(dangerNumbersBoxName) ||
      !Hive.isBoxOpen(bombNumbersBoxName)) {
    log('[BackgroundService] Required boxes not open for syncBlockedLists.');
    return;
  }
  final settingsBox = Hive.box(settingsBoxName);
  final blockedNumbersBox = Hive.box(blockedNumbersBoxName);
  final dangerNumbersBox = Hive.box<List<String>>(dangerNumbersBoxName);
  final bombNumbersBox = Hive.box<List<String>>(bombNumbersBoxName);

  try {
    // 1. 서버에서 사용자 차단 목록 가져와 Hive 업데이트
    log('[BackgroundService] Syncing user blocked numbers...');
    try {
      final serverNumbers = await BlockApi.getBlockedNumbers();
      final numbersToSave =
          (serverNumbers ?? []).map((n) => normalizePhone(n)).toList();
      await blockedNumbersBox.clear(); // 기존 목록 삭제
      await blockedNumbersBox.addAll(numbersToSave); // 새 목록 추가
      log(
        '[BackgroundService] Synced user blocked numbers: ${numbersToSave.length}',
      );
    } catch (e) {
      log('[BackgroundService] Error syncing user blocked numbers: $e');
      // 사용자 목록 동기화 실패 시 어떻게 처리할지? (예: 로컬 유지 또는 에러 로깅)
    }

    // 2. 위험 번호 업데이트
    final isAutoBlockDanger =
        settingsBox.get('isAutoBlockDanger', defaultValue: false) as bool;
    if (isAutoBlockDanger) {
      log('[BackgroundService] Syncing danger numbers...');
      try {
        final dangerNumbersResult = await SearchApi.getPhoneNumbersByType(99);
        final dangerNumbersList =
            dangerNumbersResult
                .map((n) => normalizePhone(n.phoneNumber))
                .toList();
        await dangerNumbersBox.put('list', dangerNumbersList); // 'list' 키에 저장
        log(
          '[BackgroundService] Synced danger numbers: ${dangerNumbersList.length}',
        );
      } catch (e) {
        log('[BackgroundService] Error syncing danger numbers: $e');
      }
    } else {
      // 설정 꺼져있으면 로컬 데이터 삭제 (선택적)
      await dangerNumbersBox.delete('list');
      log(
        '[BackgroundService] Cleared local danger numbers as setting is off.',
      );
    }

    // 3. 콜폭 번호 업데이트
    final isBombCallsBlocked =
        settingsBox.get('isBombCallsBlocked', defaultValue: false) as bool;
    final bombCallsCount =
        settingsBox.get('bombCallsCount', defaultValue: 0) as int;
    if (isBombCallsBlocked && bombCallsCount > 0) {
      log(
        '[BackgroundService] Syncing bomb call numbers (count: $bombCallsCount)...',
      );
      try {
        final bombNumbersResult = await BlockApi.getBlockNumbers(
          bombCallsCount,
        );
        final bombNumbersList =
            (bombNumbersResult ?? [])
                .map((n) => normalizePhone(n['phoneNumber'] as String? ?? ''))
                .toList();
        await bombNumbersBox.put('list', bombNumbersList); // 'list' 키에 저장
        log(
          '[BackgroundService] Synced bomb call numbers: ${bombNumbersList.length}',
        );
      } catch (e) {
        log('[BackgroundService] Error syncing bomb call numbers: $e');
      }
    } else {
      // 설정 꺼져있으면 로컬 데이터 삭제 (선택적)
      await bombNumbersBox.delete('list');
      log(
        '[BackgroundService] Cleared local bomb call numbers as setting is off.',
      );
    }

    log('[BackgroundService] syncBlockedLists finished.');
  } catch (e, st) {
    log('[BackgroundService] General error during syncBlockedLists: $e\n$st');
  }
}
