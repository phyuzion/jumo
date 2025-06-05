// lib/services/app_background_service.dart

import 'dart:async';
import 'dart:developer';
import 'dart:ui'; // DartPluginRegistrant 사용 위해 추가
import 'dart:isolate'; // <<< Isolate 사용 위해 추가 >>>
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart'; // AndroidServiceInstance 사용 위해 추가
import 'package:flutter_local_notifications/flutter_local_notifications.dart'; // <<< Local Notifications 임포트 추가
import 'package:mobile/graphql/notification_api.dart';
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
import 'package:mobile/repositories/blocked_history_repository.dart';
import 'package:mobile/services/native_methods.dart'; // <<< 추가: NativeMethods 사용 위해 임포트
//import 'package:system_alert_window/system_alert_window.dart';

// const int CALL_STATUS_NOTIFICATION_ID = 1111;
const String FOREGROUND_SERVICE_CHANNEL_ID = 'jumo_foreground_service_channel';
const int FOREGROUND_SERVICE_NOTIFICATION_ID = 777;

int ongoingSeconds = 0; // 통화 시간 추적
Timer? callTimer; // 통화 타이머
String _currentNumberForTimer = ''; // 타이머용 현재 번호
String _currentCallerNameForTimer = ''; // 타이머용 현재 발신자 이름

// 통화 상태 캐싱을 위한 변수 추가
bool _cachedCallActive = false;
String _cachedCallNumber = '';
String _cachedCallerName = '';
bool _uiInitialized = false;

// 통화 상태 체크를 위한 변수 추가
Timer? callStateCheckTimer;
bool _isFirstCheck = true;
String _lastCheckedCallState = 'IDLE';
String _lastCheckedCallNumber = '';

@pragma('vm:entry-point')
Future<void> onStart(ServiceInstance service) async {
  log(
    '[BackgroundService][onStart] STARTING SERVICE - THIS SHOULD ALWAYS APPEAR',
  );
  // NOTE: Flutter 3.19+ 에서는 백그라운드 Isolate 에서 모든 플러그인을 다시 등록할 필요가 없습니다.
  // 특히 flutter_background_service_android 가 두 번째 Isolate 에 Attach 되면
  // "This class should only be used in the main isolate" 예외를 던집니다.
  // 아래 호출을 제거해도 Local-Notifications 등 주요 플러그인은 정상 동작하며,
  // 일부 구형 Flutter (<3.0) 에서만 필요했기 때문에 지금은 제외합니다.

  log(
    '[BackgroundService][onStart] Service instance started. Isolate: ${Isolate.current.hashCode}',
  );

  // <<< 1. 시작 시 짧은 딜레이 추가 >>>
  await Future.delayed(const Duration(milliseconds: 100));
  log('[BackgroundService][onStart] Initial delay complete.');

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // <<< Hive 초기화 >>>
  bool hiveInitialized = false;
  late AuthRepository authRepository;
  late SettingsRepository settingsRepository;
  late NotificationRepository notificationRepository;
  late BlockedNumberRepository blockedNumberRepository;
  late BlockedHistoryRepository blockedHistoryRepository;
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
    // 통화가 완전히 끝났을 때만 ongoingSeconds 초기화
    ongoingSeconds = 0;
  }

  // <<< 타이머 시작 함수 정의 (간소화된 버전) >>>
  void _startCallTimerBackground() {
    // 이미 실행 중인 타이머가 있으면 중지
    if (callTimer?.isActive ?? false) {
      callTimer!.cancel();
      log('[BackgroundService] Existing call timer stopped for restart.');
    }

    // 기존 타이머가 없는 경우에만 ongoingSeconds 초기화
    // 앱 재시작 시에는 이전 타이머 값을 유지함
    if (callTimer == null && ongoingSeconds == 0) {
      log('[BackgroundService] Initializing new call timer with 0 seconds.');
      // 새 통화에 대해서만 타이머 초기화
    }

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
        // 타임아웃 시간 증가 (700ms -> 1500ms)
        nativeCallDetails = await nativeStateCompleter.future.timeout(
          const Duration(milliseconds: 1500),
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

  // 통화 상태를 주기적으로 체크하는 타이머 설정
  void startCallStateCheckTimer() {
    // 이미 실행 중인 타이머가 있으면 취소
    callStateCheckTimer?.cancel();

    // 첫 번째 체크 플래그 설정
    _isFirstCheck = true;

    // 1초마다 통화 상태 체크
    callStateCheckTimer = Timer.periodic(const Duration(seconds: 1), (
      timer,
    ) async {
      try {
        // 네이티브 통화 상태 확인 - 직접 호출 대신 메인 isolate에 요청
        service.invoke('requestCurrentCallStateFromAppControllerForTimer');
        final Completer<Map<String, dynamic>?> nativeStateCompleter =
            Completer();
        StreamSubscription? nativeStateSubscription;
        nativeStateSubscription = service
            .on('responseCurrentCallStateToBackgroundForTimer')
            .listen((event) {
              if (!nativeStateCompleter.isCompleted) {
                nativeStateCompleter.complete(event);
                nativeStateSubscription?.cancel();
              }
            });

        Map<String, dynamic>? nativeCallState;
        try {
          // 타임아웃 시간 설정
          nativeCallState = await nativeStateCompleter.future.timeout(
            const Duration(milliseconds: 1500),
          );
        } catch (e) {
          log(
            '[BackgroundService][CallStateCheck] Timeout or error waiting for native state: $e',
          );
          nativeStateSubscription?.cancel();
          return;
        }

        final String state = nativeCallState?['state'] as String? ?? 'IDLE';
        final String number = nativeCallState?['number'] as String? ?? '';

        // 상태 변경 감지 (첫 체크 또는 상태 변경 시에만 처리)
        bool stateChanged =
            state != _lastCheckedCallState || number != _lastCheckedCallNumber;

        if (_isFirstCheck || stateChanged) {
          // 상태 업데이트
          _lastCheckedCallState = state;
          _lastCheckedCallNumber = number;

          if (state.toUpperCase() == 'ACTIVE' ||
              state.toUpperCase() == 'DIALING') {
            log(
              '[BackgroundService][CallStateCheck] Active call detected: $number',
            );

            // 통화 중 상태 캐싱
            _cachedCallActive = true;
            _cachedCallNumber = number;

            // 타이머가 실행 중이 아닐 때만 시작 (통화 시간 리셋 방지)
            if (callTimer == null || !(callTimer?.isActive ?? false)) {
              log('[BackgroundService][CallStateCheck] Starting call timer');
              _startCallTimerBackground();
            }

            // UI 업데이트 메시지 전송
            if (_uiInitialized) {
              service.invoke('updateUiCallState', {
                'state': 'active',
                'number': number,
                'callerName': _cachedCallerName,
                'connected': true,
                'duration': ongoingSeconds,
                'reason': 'periodic_check',
              });
            }
          } else if (state.toUpperCase() == 'IDLE' && _cachedCallActive) {
            log(
              '[BackgroundService][CallStateCheck] Call ended, stopping timer',
            );

            // 통화 종료 상태 캐싱
            _cachedCallActive = false;
            _cachedCallNumber = '';
            _cachedCallerName = '';

            // 타이머 중지
            _stopCallTimerBackground();

            // UI 업데이트 메시지 전송
            if (_uiInitialized) {
              service.invoke('updateUiCallState', {
                'state': 'ended',
                'number': _lastCheckedCallNumber, // 마지막으로 확인된 번호 전달
                'callerName': '',
                'connected': false,
                'duration': 0,
                'reason': 'periodic_check_ended',
              });

              // 포그라운드 알림 업데이트
              if (service is AndroidServiceInstance) {
                if (await service.isForegroundService()) {
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
                }
              }
            }
          }
        }

        // 첫 번째 체크 완료 후 플래그 해제
        if (_isFirstCheck) {
          _isFirstCheck = false;
        }
      } catch (e) {
        log(
          '[BackgroundService][CallStateCheck] Error checking call state: $e',
        );
      }
    });

    log(
      '[BackgroundService] Call state check timer started (1-second intervals)',
    );
  }

  // --- 주기적 작업들 ---
  Timer? notificationTimer;
  Timer? blockSyncTimer;

  // UI 초기화 완료 신호를 처리하는 리스너 추가
  service.on('appInitialized').listen((event) async {
    log('[BackgroundService] Received appInitialized signal from main app');
    _uiInitialized = true;

    // UI가 초기화되었으면 캐싱된 통화 상태를 확인하고 필요하면 UI에 전송
    if (_cachedCallActive && _cachedCallNumber.isNotEmpty) {
      log(
        '[BackgroundService] UI initialized. Sending cached call state: Number=$_cachedCallNumber',
      );

      // UI에 캐싱된 통화 상태 정보 전송
      service.invoke('updateUiCallState', {
        'state': 'active',
        'number': _cachedCallNumber,
        'callerName': _cachedCallerName,
        'connected': true,
        'duration': ongoingSeconds,
        'reason': 'cached_state_after_ui_init',
      });

      // 타이머가 활성화되지 않았다면 시작
      if (callTimer == null || !(callTimer?.isActive ?? false)) {
        _startCallTimerBackground();
      }
    }

    // 통화 상태 체크 타이머 시작
    startCallStateCheckTimer();
  });

  // 알림 확인 타이머 (10초마다 실행)
  log('[BackgroundService] SETTING UP NOTIFICATION TIMER - THIS SHOULD APPEAR');
  notificationTimer = Timer.periodic(const Duration(seconds: 10), (
    timer,
  ) async {
    log(
      '[BackgroundService] Periodic task (Notifications) RUNNING - TIMER TICK',
    );
    log(
      '[BackgroundService] Periodic task (Notifications - 10 min) running...',
    );
    // 서버 알림 확인 로직 - 메인 isolate에 요청
    try {
      // 직접 API 호출 대신 메인 isolate에 요청
      log('[BackgroundService] Requesting notifications from main isolate');
      service.invoke('requestNotifications');
    } catch (e) {
      log('[BackgroundService] Error requesting notifications from main: $e');
    }
  });

  // 노티피케이션 응답 리스너 추가
  service.on('notificationsResponse').listen((event) {
    try {
      final notiList = event?['notifications'] as List<dynamic>?;
      log(
        '[BackgroundService] Received notifications from main isolate: ${notiList?.length ?? 0} items',
      );

      if (notiList == null || notiList.isEmpty) return;

      // 만료된 알림 제거 요청
      service.invoke('removeExpiredNotifications');

      // 서버에 있는 알림 ID 목록을 추출
      final serverNotificationIds = <String>[];

      // 각 알림 처리
      for (final n in notiList) {
        final sid = (n['id'] ?? '').toString();
        if (sid.isEmpty) continue;

        // 서버 ID 목록에 추가
        serverNotificationIds.add(sid);

        service.invoke('saveNotification', {
          'id': sid,
          'title': n['title'] as String? ?? 'No Title',
          'message': n['message'] as String? ?? '...',
          'validUntil': n['validUntil'],
        });
      }

      // 서버에 없는 노티피케이션을 로컬에서 삭제 요청
      if (serverNotificationIds.isNotEmpty) {
        log(
          '[BackgroundService] Requesting to sync local notifications with server IDs: ${serverNotificationIds.length} IDs',
        );
        service.invoke('syncNotificationsWithServer', {
          'serverIds': serverNotificationIds,
        });
      }
    } catch (e) {
      log('[BackgroundService] Error processing notifications response: $e');
    }
  });

  // 노티피케이션 에러 리스너 추가
  service.on('notificationsError').listen((event) {
    final errorMsg = event?['error'] as String? ?? 'Unknown error';
    log(
      '[BackgroundService] Error from main isolate when fetching notifications: $errorMsg',
    );
  });

  // 차단 목록 동기화 타이머 (1시간 주기 - 호출 확인)
  blockSyncTimer = Timer.periodic(const Duration(hours: 1), (timer) async {
    log(
      '[BackgroundService] Starting periodic blocked/danger/bomb numbers sync...',
    );
    await syncBlockedLists(); // <<< 주기적으로 헬퍼 호출 확인
  });

  // 캐싱된 통화 상태 확인 요청 처리 리스너
  service.on('checkCachedCallState').listen((event) async {
    log(
      '[BackgroundService] Received checkCachedCallState request from main app',
    );

    // UI가 초기화되었고 캐싱된 통화 상태가 있으면 UI에 전송
    if (_uiInitialized && _cachedCallActive && _cachedCallNumber.isNotEmpty) {
      log(
        '[BackgroundService] Responding with cached active call state for number: $_cachedCallNumber',
      );

      // UI에 캐싱된 통화 상태 정보 전송
      service.invoke('updateUiCallState', {
        'state': 'active',
        'number': _cachedCallNumber,
        'callerName': _cachedCallerName,
        'connected': true,
        'duration': ongoingSeconds,
        'reason': 'cached_state_check_response',
      });

      // 타이머가 활성화되지 않았다면 시작
      if (callTimer == null || !(callTimer?.isActive ?? false)) {
        _startCallTimerBackground();
      }
    } else {
      // 특수 전화번호 처리를 위한 추가 확인
      try {
        service.invoke('requestCurrentCallStateFromAppControllerForTimer');
        final Completer<Map<String, dynamic>?> completer = Completer();
        StreamSubscription? subscription;

        subscription = service
            .on('responseCurrentCallStateToBackgroundForTimer')
            .listen((callState) {
              if (!completer.isCompleted) {
                completer.complete(callState);
                subscription?.cancel();
              }
            });

        // 더 긴 타임아웃 설정 (2초)
        Future.delayed(const Duration(seconds: 2), () {
          if (!completer.isCompleted) {
            completer.complete(null);
            subscription?.cancel();
          }
        });

        final Map<String, dynamic>? currentState = await completer.future;
        if (currentState != null) {
          final String state = currentState['state'] as String? ?? 'IDLE';
          final String number = currentState['number'] as String? ?? '';

          log(
            '[BackgroundService] Additional call state check: state=$state, number=$number',
          );

          // 통화 중인 경우 (특히 1644와 같은 특수 번호 처리)
          if ((state.toUpperCase() == 'ACTIVE' ||
                  state.toUpperCase() == 'DIALING') &&
              number.isNotEmpty) {
            // 캐싱 업데이트
            _cachedCallActive = true;
            _cachedCallNumber = number;

            // UI에 상태 전송
            service.invoke('updateUiCallState', {
              'state': 'active',
              'number': number,
              'callerName': '',
              'connected': true,
              'duration': 0,
              'reason': 'special_number_check_response',
            });

            // 타이머 시작
            if (callTimer == null || !(callTimer?.isActive ?? false)) {
              _currentNumberForTimer = number;
              _startCallTimerBackground();
            }
          }
        }
      } catch (e) {
        log('[BackgroundService] Error during additional call state check: $e');
      }
    }
  });

  // 기존 callStateChanged 리스너
  service.on('callStateChanged').listen((event) async {
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

    // 통화 상태 캐싱 업데이트
    if (state == 'active') {
      _cachedCallActive = true;
      _cachedCallNumber = number;
      _cachedCallerName = callerName;
    } else if (state == 'ended') {
      _cachedCallActive = false;
      _cachedCallNumber = '';
      _cachedCallerName = '';
    }

    // <<< 타이머 로직 호출 >>>
    if (state == 'active') {
      // 새 통화인 경우에만 타이머 시작
      if (!isConnected &&
          (callTimer == null || !(callTimer?.isActive ?? false))) {
        // 새 통화 시작 (아직 연결되지 않음)
        _startCallTimerBackground();
      } else if (isConnected) {
        // 이미 연결된 통화 - 타이머가 없는 경우에만 시작
        if (callTimer == null || !(callTimer?.isActive ?? false)) {
          _startCallTimerBackground();
        }
      }
    } else if (state == 'ended') {
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
        log('[BackgroundService] Sending requestDefaultDialerStatus to main.');
        service.invoke('requestDefaultDialerStatus');

        final Completer<bool> completer = Completer<bool>();
        StreamSubscription? subscription;

        subscription = service.on('respondDefaultDialerStatus').listen((event) {
          final bool isDefault = event?['isDefault'] as bool? ?? false;
          log(
            '[BackgroundService] Received respondDefaultDialerStatus: $isDefault',
          );
          if (!completer.isCompleted) {
            completer.complete(isDefault);
            subscription?.cancel();
          }
        });

        Future.delayed(const Duration(seconds: 2), () {
          if (!completer.isCompleted) {
            log(
              '[BackgroundService] Timeout waiting for respondDefaultDialerStatus.',
            );
            completer.complete(false);
            subscription?.cancel();
          }
        });

        bool isDefaultDialer = await completer.future;
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

  await performInitialBackgroundTasks(service);
  log(
    '[BackgroundService][onStart] Initial background tasks completed. Service is ready.',
  );

  // 백그라운드 서비스 시작 시 통화 상태 체크 타이머 시작
  // UI가 초기화되지 않았더라도 백그라운드에서 상태를 캐싱하기 위해 시작
  startCallStateCheckTimer();

  log(
    '[BackgroundService] Listening to background service UI updates and notification requests.',
  );

  // ping 리스너 추가 (서비스 응답성 확인용)
  service.on('ping').listen((event) {
    log('[BackgroundService] Received ping, responding with pong.');
    service.invoke('pong', {
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  });
}

Future<void> performInitialBackgroundTasks(ServiceInstance service) async {
  // <<< 로그 추가 >>>
  log(
    '[BackgroundService][performInitialBackgroundTasks] Starting initial tasks...',
  );

  // 백그라운드 서비스 시작 시 현재 통화 상태 확인 및 캐싱
  try {
    // 1. 메인 앱에 현재 통화 상태 요청
    service.invoke('requestCurrentCallStateFromAppControllerForTimer');

    // 2. 응답 대기 설정
    final Completer<Map<String, dynamic>?> completer = Completer();
    StreamSubscription? subscription;
    subscription = service
        .on('responseCurrentCallStateToBackgroundForTimer')
        .listen((event) {
          if (!completer.isCompleted) {
            completer.complete(event);
            subscription?.cancel();
          }
        });

    // 3. 타임아웃 설정 (1초로 감소)
    Future.delayed(const Duration(seconds: 1), () {
      if (!completer.isCompleted) {
        log('[BackgroundService] Timeout waiting for initial call state.');
        completer.complete(null);
        subscription?.cancel();
      }
    });

    // 4. 응답 처리
    final Map<String, dynamic>? callState = await completer.future;
    if (callState != null) {
      final String state = callState['state'] as String? ?? 'IDLE';
      final String number = callState['number'] as String? ?? '';

      log(
        '[BackgroundService] Initial call state check: state=$state, number=$number',
      );

      // 통화 중인 경우 상태 캐싱
      if (state.toUpperCase() == 'ACTIVE' || state.toUpperCase() == 'DIALING') {
        _cachedCallActive = true;
        _cachedCallNumber = number;
        _cachedCallerName = ''; // 이름은 아직 모름

        log('[BackgroundService] Cached active call state: number=$number');

        // 참고: 여기서는 UI에 바로 메시지를 보내지 않음
        // UI가 초기화된 후 appInitialized 이벤트에서 캐싱된 상태를 전송
      }
    }
  } catch (e) {
    log('[BackgroundService] Error checking initial call state: $e');
  }

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
