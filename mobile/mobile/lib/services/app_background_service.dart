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
import 'package:mobile/graphql/search_api.dart';
import 'package:mobile/graphql/block_api.dart';
import 'package:mobile/utils/constants.dart';
import 'package:flutter_broadcasts_4m/flutter_broadcasts.dart';
import 'package:mobile/repositories/auth_repository.dart';
import 'package:mobile/repositories/settings_repository.dart'; // <<< 추가
import 'package:mobile/repositories/notification_repository.dart'; // <<< 추가
import 'package:mobile/main.dart';
import 'package:mobile/repositories/blocked_number_repository.dart'; // <<< 추가
import 'package:mobile/repositories/blocked_history_repository.dart'; // <<< 추가
import 'package:mobile/repositories/sync_state_repository.dart'; // <<< 추가
//import 'package:system_alert_window/system_alert_window.dart';

const int CALL_STATUS_NOTIFICATION_ID = 1111;
const String FOREGROUND_SERVICE_CHANNEL_ID = 'jumo_foreground_service_channel';
const int FOREGROUND_SERVICE_NOTIFICATION_ID = 777;

int ongoingSeconds = 0; // 통화 시간 추적
Timer? callTimer; // 통화 타이머
String _currentNumberForTimer = ''; // 타이머용 현재 번호
String _currentCallerNameForTimer = ''; // 타이머용 현재 발신자 이름

@pragma('vm:entry-point')
Future<void> onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  log(
    '[BackgroundService][onStart] Service instance started. Isolate: ${Isolate.current.hashCode}',
  );

  // <<< 1. 시작 시 짧은 딜레이 추가 >>>
  await Future.delayed(const Duration(milliseconds: 500));
  log('[BackgroundService][onStart] Initial delay complete.');

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // <<< Hive 초기화 >>>
  bool hiveInitialized = false;
  late AuthRepository authRepository;
  late SettingsRepository settingsRepository;
  late NotificationRepository notificationRepository;
  late BlockedNumberRepository blockedNumberRepository;
  late BlockedHistoryRepository blockedHistoryRepository; // <<< 추가
  late SyncStateRepository syncStateRepository; // <<< 추가
  try {
    final appDocumentDir = await getApplicationDocumentsDirectory();
    Hive.init(appDocumentDir.path);
    if (!Hive.isAdapterRegistered(BlockedHistoryAdapter().typeId)) {
      Hive.registerAdapter(BlockedHistoryAdapter());
    }

    // <<< AuthRepository 등록 >>>
    final authBox = await Hive.openBox('auth');
    authRepository = HiveAuthRepository(authBox);
    if (!getIt.isRegistered<AuthRepository>()) {
      getIt.registerSingleton<AuthRepository>(authRepository);
      log('[BackgroundService][onStart] AuthRepository registered in GetIt.');
    } else {
      log(
        '[BackgroundService][onStart] AuthRepository already registered in GetIt.',
      );
    }

    // <<< SettingsRepository 등록 >>>
    final settingsBox = await Hive.openBox('settings');
    settingsRepository = HiveSettingsRepository(settingsBox);
    if (!getIt.isRegistered<SettingsRepository>()) {
      getIt.registerSingleton<SettingsRepository>(settingsRepository);
      log(
        '[BackgroundService][onStart] SettingsRepository registered in GetIt.',
      );
    } else {
      log(
        '[BackgroundService][onStart] SettingsRepository already registered in GetIt.',
      );
    }

    // <<< NotificationRepository 등록 >>>
    final notificationsBox = await Hive.openBox('notifications'); // <<< 문자열 사용
    final displayNotiIdsBox = await Hive.openBox(
      'display_noti_ids',
    ); // <<< 문자열 사용
    notificationRepository = HiveNotificationRepository(
      notificationsBox,
      displayNotiIdsBox,
    );
    if (!getIt.isRegistered<NotificationRepository>()) {
      getIt.registerSingleton<NotificationRepository>(notificationRepository);
      log(
        '[BackgroundService][onStart] NotificationRepository registered in GetIt.',
      );
    } else {
      log(
        '[BackgroundService][onStart] NotificationRepository already registered in GetIt.',
      );
    }

    // <<< BlockedNumberRepository 등록 >>>
    final blockedNumbersBox = await Hive.openBox('blocked_numbers');
    final dangerNumbersBox = await Hive.openBox<List<String>>('danger_numbers');
    final bombNumbersBox = await Hive.openBox<List<String>>('bomb_numbers');
    blockedNumberRepository = HiveBlockedNumberRepository(
      blockedNumbersBox,
      dangerNumbersBox,
      bombNumbersBox,
    );
    if (!getIt.isRegistered<BlockedNumberRepository>()) {
      getIt.registerSingleton<BlockedNumberRepository>(blockedNumberRepository);
      log(
        '[BackgroundService][onStart] BlockedNumberRepository registered in GetIt.',
      );
    } else {
      log(
        '[BackgroundService][onStart] BlockedNumberRepository already registered in GetIt.',
      );
    }

    // <<< BlockedHistoryRepository 등록 >>>
    final blockedHistoryBox = await Hive.openBox<BlockedHistory>(
      'blocked_history',
    );
    blockedHistoryRepository = HiveBlockedHistoryRepository(blockedHistoryBox);
    if (!getIt.isRegistered<BlockedHistoryRepository>()) {
      getIt.registerSingleton<BlockedHistoryRepository>(
        blockedHistoryRepository,
      );
      log(
        '[BackgroundService][onStart] BlockedHistoryRepository registered in GetIt.',
      );
    } else {
      log(
        '[BackgroundService][onStart] BlockedHistoryRepository already registered in GetIt.',
      );
    }

    // <<< SyncStateRepository 등록 >>>
    final syncStateBox = await Hive.openBox('last_sync_state');
    syncStateRepository = HiveSyncStateRepository(syncStateBox);
    if (!getIt.isRegistered<SyncStateRepository>()) {
      getIt.registerSingleton<SyncStateRepository>(syncStateRepository);
      log(
        '[BackgroundService][onStart] SyncStateRepository registered in GetIt.',
      );
    } else {
      log(
        '[BackgroundService][onStart] SyncStateRepository already registered in GetIt.',
      );
    }

    // <<< 나머지 Box 열기 >>>
    // settingsBox는 이미 열었음
    await Hive.openBox('call_logs');

    hiveInitialized = true;
    log('[BackgroundService][onStart] Hive initialized successfully.');
  } catch (e) {
    log(
      '[BackgroundService][onStart] Error initializing Hive or Repositories: $e',
    ); // 로그 메시지 수정
    service.stopSelf();
    return;
  }
  if (!hiveInitialized) {
    log(
      '[BackgroundService][onStart] Hive initialization failed. Stopping service.',
    );
    service.stopSelf();
    return;
  }

  // <<< 3. 초기 알림 설정 (Hive 초기화 이후 + 추가 딜레이) >>>
  try {
    await Future.delayed(const Duration(milliseconds: 200)); // 추가 딜레이
    if (service is AndroidServiceInstance) {
      if (await service.isForegroundService()) {
        log(
          '[BackgroundService] Setting initial foreground notification (delayed).',
        );
        flutterLocalNotificationsPlugin.show(
          FOREGROUND_SERVICE_NOTIFICATION_ID,
          'KOLPON',
          '',
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
          payload: 'idle',
        );
        log('[BackgroundService] Initial foreground notification set.');
      } else {
        log(
          '[BackgroundService] Service is not in foreground mode, skipping initial notification.',
        );
      }
    }
  } catch (e) {
    log('[BackgroundService][onStart] Error setting initial notification: $e');
  }

  // --- Helper Function 정의 --- (코드 순서 변경 가능성에 유의)
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

  // <<< 새로운 함수: 메인 Isolate로부터 현재 통화 상태 가져오기 >>>
  Future<Map<String, dynamic>> _fetchCurrentCallStateFromMain() async {
    final completer = Completer<Map<String, dynamic>>();
    StreamSubscription? subscription;

    subscription = service.on('respondCurrentCallStateToService').listen((
      event,
    ) {
      final Map<String, dynamic> callDetails = Map<String, dynamic>.from(
        event ?? {},
      );
      log(
        '[BackgroundService] Received respondCurrentCallStateToService: $callDetails',
      );
      if (!completer.isCompleted) {
        completer.complete(callDetails);
      }
      subscription?.cancel();
    });

    Future.delayed(const Duration(seconds: 3), () {
      // 타임아웃 (3초)
      if (!completer.isCompleted) {
        log(
          '[BackgroundService] Timeout waiting for respondCurrentCallStateToService.',
        );
        completer.complete({'state': 'TIMEOUT_FETCHING_MAIN', 'number': null});
        subscription?.cancel();
      }
    });

    log(
      '[BackgroundService] Sending requestCurrentCallStateFromBackground to main.',
    );
    service.invoke('requestCurrentCallStateFromBackground');

    return completer.future;
  }

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

  // <<< 타이머 시작 함수 정의 (간소화된 버전) >>>
  void _startCallTimerBackground() {
    _stopCallTimerBackground();
    ongoingSeconds = 0;
    callTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      ongoingSeconds++;

      // 네이티브 통화 상태 확인 요청
      service.invoke('requestCurrentCallStateFromAppControllerForTimer');
      final Completer<Map<String, dynamic>?> nativeStateCompleter = Completer();
      StreamSubscription? nativeStateSubscription;
      nativeStateSubscription = service
          .on('responseCurrentCallStateToBackgroundForTimer')
          .listen((event) {
            if (!nativeStateCompleter.isCompleted) {
              nativeStateCompleter.complete(event);
              nativeStateSubscription?.cancel();
            }
          });

      Map<String, dynamic>? nativeCallDetails;
      try {
        nativeCallDetails = await nativeStateCompleter.future.timeout(
          const Duration(milliseconds: 700),
        );
      } catch (e) {
        log(
          '[BackgroundService][TimerTick] Timeout or error waiting for native state: $e',
        );
        nativeStateSubscription?.cancel();
        // 네이티브 상태를 못 가져오면, 다음 틱에서 다시 시도. (또는 여기서 'ended' 강제 전송도 고려 가능)
        return;
      }

      final String nativeState =
          nativeCallDetails?['state'] as String? ?? 'UNKNOWN';
      final String currentNumberInTimer = _currentNumberForTimer;
      final String currentCallerNameInTimer = _currentCallerNameForTimer;

      // FlutterLocalNotificationsPlugin 인스턴스 가져오기 (onStart에서 초기화된 것을 사용)
      // 실제로는 onStart에서 생성된 인스턴스를 계속 사용해야 하므로, 이 부분은 onStart의 것을 참조하도록 수정 필요.
      // 여기서는 임시로 로컬 변수를 선언하지만, 실제 사용 시에는 onStart의 flutterLocalNotificationsPlugin를 사용해야 합니다.
      final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
          FlutterLocalNotificationsPlugin();

      if (nativeState.toUpperCase() != 'ACTIVE' &&
          nativeState.toUpperCase() != 'DIALING') {
        log(
          '[BackgroundService][TimerTickDebug] Native state is $nativeState. Call seems ended. Stopping timer.',
        );
        _stopCallTimerBackground(); // 타이머 중지

        // UI에 통화 종료 상태 알림 -> 이 이벤트는 main.dart의 _listenToBackgroundService에서 처리되어
        // CallStateProvider를 업데이트하고, CallStateProvider는 알림 변경 등 후속 조치를 할 수 있음.
        service.invoke('updateUiCallState', {
          'state': 'ended',
          'number': currentNumberInTimer,
          'callerName': currentCallerNameInTimer,
          'connected': false,
          'duration': ongoingSeconds,
          'reason': 'sync_ended_native_not_active ($nativeState)',
        });

        // 백그라운드 서비스의 'callStateChanged' 리스너에게도 'ended' 상태를 알려서
        // 포그라운드 알림을 기본 상태로 되돌리도록 할 수 있음.
        // 이렇게 하면 알림 관리가 'callStateChanged' 리스너로 일원화됨.
        service.invoke('callStateChanged', {
          'state': 'ended',
          'number': currentNumberInTimer,
          'callerName': currentCallerNameInTimer,
          'connected': false,
          'reason': 'sync_ended_native_not_active ($nativeState)',
        });
      } else {
        // 네이티브 상태가 ACTIVE 또는 DIALING임. UI에 'active' 상태 및 시간 업데이트
        log(
          '[BackgroundService][TimerTickDebug] Native state is $nativeState. Timer continues for $currentNumberInTimer. Duration: $ongoingSeconds',
        );

        if (service is AndroidServiceInstance) {
          if (await service.isForegroundService()) {
            String title =
                '통화중... (${_formatDurationBackground(ongoingSeconds)})';
            String content =
                '$currentCallerNameInTimer ($currentNumberInTimer)';
            String payload = 'active:$currentNumberInTimer';

            // 포그라운드 알림 업데이트
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

        // UI에 'active' 상태 업데이트
        service.invoke('updateUiCallState', {
          'state': 'active',
          'number': currentNumberInTimer,
          'callerName': currentCallerNameInTimer,
          'connected': true,
          'duration': ongoingSeconds,
          'reason': '',
        });
      }
    });
    log(
      '[BackgroundService] Call timer started with native state check (simplified).',
    );
  }

  log('[BackgroundService] Setting up periodic timers and event listeners...');

  // --- 주기적 작업들 ---
  Timer? notificationTimer;
  Timer? contactSyncTimer;
  Timer? blockSyncTimer;

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

    final state = event?['state'] as String?;
    final number = event?['number'] as String? ?? '';
    final callerName = event?['callerName'] as String? ?? '';
    final isConnected = event?['connected'] as bool? ?? false;
    final reason = event?['reason'] as String? ?? '';

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
      String title = 'KOLPON';
      String content = '';
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
          title = 'KOLPON'; // 종료 시 기본으로 복원
          content = '';
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
  // <<< Box 이름 상수 제거 또는 유지 (Repository 내부에서만 사용) >>>

  // <<< Repository 인스턴스 가져오기 >>>
  late SettingsRepository settingsRepository;
  late BlockedNumberRepository blockedNumberRepository;
  try {
    settingsRepository = getIt<SettingsRepository>();
    blockedNumberRepository = getIt<BlockedNumberRepository>();
  } catch (e) {
    log(
      '[BackgroundService][syncBlockedLists] Failed to get Repositories from GetIt: $e',
    );
    return;
  }

  // <<< Box 직접 접근 제거 >>>
  // final blockedNumbersBox = Hive.box(blockedNumbersBoxName);
  // final dangerNumbersBox = Hive.box<List<String>>(dangerNumbersBoxName);
  // final bombNumbersBox = Hive.box<List<String>>(bombNumbersBoxName);

  try {
    // 1. 서버에서 사용자 차단 목록 가져와 Repository 통해 저장
    log('[BackgroundService] Syncing user blocked numbers...');
    try {
      final serverNumbers = await BlockApi.getBlockedNumbers();
      final numbersToSave =
          (serverNumbers ?? []).map((n) => normalizePhone(n)).toList();
      // <<< Repository 사용 >>>
      await blockedNumberRepository.saveAllUserBlockedNumbers(numbersToSave);
      log(
        '[BackgroundService] Synced user blocked numbers: ${numbersToSave.length}',
      );
    } catch (e) {
      log('[BackgroundService] Error syncing user blocked numbers: $e');
    }

    // 2. 위험 번호 업데이트 (SettingsRepository 및 BlockedNumberRepository 사용)
    final isAutoBlockDanger = await settingsRepository.isAutoBlockDanger();
    if (isAutoBlockDanger) {
      log('[BackgroundService] Syncing danger numbers...');
      try {
        final dangerNumbersResult = await SearchApi.getPhoneNumbersByType(99);
        final dangerNumbersList =
            dangerNumbersResult
                .map((n) => normalizePhone(n.phoneNumber))
                .toList();
        // <<< Repository 사용 >>>
        await blockedNumberRepository.saveDangerNumbers(dangerNumbersList);
        log(
          '[BackgroundService] Synced danger numbers: ${dangerNumbersList.length}',
        );
      } catch (e) {
        log('[BackgroundService] Error syncing danger numbers: $e');
      }
    } else {
      // <<< Repository 사용 >>>
      await blockedNumberRepository.clearDangerNumbers();
      log(
        '[BackgroundService] Cleared local danger numbers as setting is off.',
      );
    }

    // 3. 콜폭 번호 업데이트 (SettingsRepository 및 BlockedNumberRepository 사용)
    final isBombCallsBlocked = await settingsRepository.isBombCallsBlocked();
    final bombCallsCount = await settingsRepository.getBombCallsCount();
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
        // <<< Repository 사용 >>>
        await blockedNumberRepository.saveBombNumbers(bombNumbersList);
        log(
          '[BackgroundService] Synced bomb call numbers: ${bombNumbersList.length}',
        );
      } catch (e) {
        log('[BackgroundService] Error syncing bomb call numbers: $e');
      }
    } else {
      // <<< Repository 사용 >>>
      await blockedNumberRepository.clearBombNumbers();
      log(
        '[BackgroundService] Cleared local bomb call numbers as setting is off.',
      );
    }

    log('[BackgroundService] syncBlockedLists finished.');
  } catch (e, st) {
    log('[BackgroundService] General error during syncBlockedLists: $e\n$st');
  }
}
