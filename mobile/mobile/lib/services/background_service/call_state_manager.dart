import 'dart:async';
import 'dart:developer';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_broadcasts_4m/flutter_broadcasts.dart';
import 'package:mobile/services/background_service/service_constants.dart';
import 'package:mobile/services/background_service/call_timer.dart';
import 'package:mobile/services/local_notification_service.dart';

// 수신 전화 노티피케이션 ID
const int CALL_STATUS_NOTIFICATION_ID = 9876;

class CallStateManager {
  final ServiceInstance _service;
  final FlutterLocalNotificationsPlugin _notifications;
  final CallTimer _callTimer;

  // 통화 상태 캐싱을 위한 변수
  bool _cachedCallActive = false;
  String _cachedCallNumber = '';
  String _cachedCallerName = '';
  String _cachedCallState = 'idle';
  int _cachedIncomingTimestamp = 0;
  bool _uiInitialized = false;

  // 통화 상태 체크를 위한 변수
  Timer? _callStateCheckTimer;
  bool _isFirstCheck = true;
  String _lastCheckedCallState = 'IDLE';
  String _lastCheckedCallNumber = '';

  // 인코밍 콜 알림 주기적 갱신을 위한 타이머
  Timer? _incomingCallRefreshTimer;
  int _incomingCallNotificationCount = 0; // 표시 횟수 추적

  CallStateManager(this._service, this._notifications)
    : _callTimer = CallTimer(_service, _notifications);

  Future<void> initialize() async {
    _setupEventListeners();
    _setupBroadcastReceiver();
    _startCallStateCheckTimer();
  }

  void _setupEventListeners() {
    // 기본 다이얼러 설정 변경 이벤트 처리
    _service.on('defaultDialerChanged').listen((event) async {
      final bool isDefault = event?['isDefault'] as bool? ?? false;
      log('[CallStateManager][CRITICAL] 기본 다이얼러 설정 변경: isDefault=$isDefault - 상태 초기화');
      
      // 상태 완전히 초기화
      _clearCallState();
      
      // 인코밍 콜 알림 갱신 타이머 정지
      _stopIncomingCallRefreshTimer();
      
      // 수신 전화 노티피케이션 취소
      try {
        await LocalNotificationService.cancelNotification(CALL_STATUS_NOTIFICATION_ID);
        log('[CallStateManager] 기본 다이얼러 변경으로 수신 전화 노티피케이션 취소 성공');
      } catch (e) {
        log('[CallStateManager] 기본 다이얼러 변경으로 수신 전화 노티피케이션 취소 실패: $e');
      }
      
      // 타이머 중지
      _callTimer.stopCallTimer();
      
      // 포그라운드 알림 업데이트
      await _updateForegroundNotification('KOLPON', '', 'idle');
      
      // UI에 상태 초기화 알림
      if (_uiInitialized) {
        _updateUiCallState('ended', '', '', false, 0, 'default_dialer_change');
      }
    });
    
    // UI 초기화 완료 신호를 처리하는 리스너
    _service.on('appInitialized').listen((event) async {
      log('[CallStateManager] Received appInitialized signal from main app');
      _uiInitialized = true;

      // UI가 초기화되었으면 캐싱된 통화 상태를 확인하고 필요하면 UI에 전송
      if (_cachedCallActive && _cachedCallNumber.isNotEmpty) {
        log(
          '[CallStateManager] UI initialized. Sending cached call state: $_cachedCallState for Number=$_cachedCallNumber',
        );

        // 인코밍 상태 처리
        if (_cachedCallState == 'incoming') {
          // 인코밍 상태 시간 확인 (앱 시작 시에는 더 길게 유지)
          final currentTime = DateTime.now().millisecondsSinceEpoch;
          final elapsedTime = currentTime - _cachedIncomingTimestamp;

          // 앱 초기화 직후에는 더 긴 시간 동안 인코밍 상태 유지 (10초)
          final timestamp = event?['timestamp'] as int?;
          int incomingExpiryTime = 30000; // 기본 30초

          // 앱 시작 후 첫 10초 이내라면 더 긴 타임아웃 적용 (10초)
          if (timestamp != null) {
            final sinceAppInit = currentTime - timestamp;
            if (sinceAppInit < 10000) {
              // 앱 시작 후 10초 이내
              incomingExpiryTime = 10000; // 10초로 변경
              log(
                '[CallStateManager] 앱 시작 직후 인코밍 콜 유효 시간 연장: ${incomingExpiryTime}ms',
              );
            }
          }

          if (elapsedTime > incomingExpiryTime) {
            log(
              '[CallStateManager] Ignoring outdated incoming call (${elapsedTime}ms old, limit: ${incomingExpiryTime}ms)',
            );
            _clearCallState();
            return;
          }

          // 유효한 인코밍 상태 전달
          _updateUiCallState(
            'incoming',
            _cachedCallNumber,
            '', // 빈 문자열로 변경
            false,
            0,
            'cached_incoming_after_ui_init',
          );
          return;
        }

        // 활성 통화 상태 정보 전송
        _updateUiCallState(
          'active',
          _cachedCallNumber,
          '', // 빈 문자열로 변경
          true,
          _callTimer.ongoingSeconds,
          'cached_state_after_ui_init',
        );

        // 타이머가 활성화되지 않았다면 시작
        if (!_callTimer.isActive) {
          _callTimer.startCallTimer(_cachedCallNumber, _cachedCallerName);
        }
      }

      // 통화 상태 체크 타이머 시작
      _startCallStateCheckTimer();
    });

    // 캐싱된 통화 상태 확인 요청 처리 리스너
    _service.on('checkCachedCallState').listen((event) async {
      log(
        '[CallStateManager] Received checkCachedCallState request from main app',
      );

      // UI가 초기화되었고 캐싱된 통화 상태가 있으면 UI에 전송
      if (_uiInitialized && _cachedCallActive && _cachedCallNumber.isNotEmpty) {
        log(
          '[CallStateManager] Responding with cached call state: $_cachedCallState for number: $_cachedCallNumber',
        );

        // 인코밍 전화 상태인 경우 시간 확인 (30초 이상 지난 인코밍은 무시)
        if (_cachedCallState == 'incoming') {
          final currentTime = DateTime.now().millisecondsSinceEpoch;
          final elapsedTime = currentTime - _cachedIncomingTimestamp;

          // 인코밍 콜 유효성 검사 (앱 시작 시에는 더 길게 유지)
          int incomingExpiryTime = 30000; // 기본 30초

          // 앱 초기화 직후에는 더 긴 시간 동안 인코밍 상태 유지 (10초)
          final appInitializedTime = event?['timestamp'] as int?;
          if (appInitializedTime != null) {
            final sinceAppInit =
                DateTime.now().millisecondsSinceEpoch - appInitializedTime;
            if (sinceAppInit < 10000) {
              // 앱 시작 후 10초 이내
              incomingExpiryTime = 10000; // 10초로 변경
              log(
                '[CallStateManager] 앱 시작 직후 인코밍 콜 유효 시간 연장: ${incomingExpiryTime}ms',
              );
            }
          }

          // 설정된 시간보다 오래된 인코밍 콜은 이미 종료된 것으로 간주
          if (elapsedTime > incomingExpiryTime) {
            log(
              '[CallStateManager] Ignoring outdated incoming call (${elapsedTime}ms old, limit: ${incomingExpiryTime}ms)',
            );
            _clearCallState();
            return;
          }

          // 유효한 인코밍 콜 상태 전달
          _updateUiCallState(
            'incoming',
            _cachedCallNumber,
            '', // 빈 문자열로 변경
            false,
            0,
            'cached_incoming_state_response',
          );
          return;
        }

        // 활성 통화 상태 전송
        _updateUiCallState(
          'active',
          _cachedCallNumber,
          '', // 빈 문자열로 변경
          true,
          _callTimer.ongoingSeconds,
          'cached_state_check_response',
        );

        // 타이머가 활성화되지 않았다면 시작
        if (!_callTimer.isActive) {
          _callTimer.startCallTimer(_cachedCallNumber, _cachedCallerName);
        }
      } else {
        // 특수 전화번호 처리를 위한 추가 확인
        try {
          final currentState = await _getCurrentCallStateFromNative();
          if (currentState != null) {
            final String state = currentState['state'] as String? ?? 'IDLE';
            final String number = currentState['number'] as String? ?? '';

            log(
              '[CallStateManager] Additional call state check: state=$state, number=$number',
            );

            // 통화 중인 경우 (특히 1644와 같은 특수 번호 처리)
            if ((state.toUpperCase() == 'ACTIVE' ||
                    state.toUpperCase() == 'DIALING') &&
                number.isNotEmpty) {
              // 캐싱 업데이트
              _cachedCallActive = true;
              _cachedCallNumber = number;
              _cachedCallState = 'active';

              // UI에 상태 전송
              _updateUiCallState(
                'active',
                number,
                '', // 빈 문자열로 변경
                true,
                0,
                'special_number_check_response',
              );

              // 타이머 시작
              if (!_callTimer.isActive) {
                _callTimer.startCallTimer(number, '');
              }
            }
          }
        } catch (e) {
          log(
            '[CallStateManager] Error during additional call state check: $e',
          );
        }
      }
    });

    // 통화 상태 변경 처리
    _service.on('callStateChanged').listen((event) async {
      if (event == null) {
        log(
          '[CallStateManager][on:callStateChanged] Received null event. Skipping.',
        );
        return;
      }

      final state = event?['state'] as String?;
      final number = event?['number'] as String? ?? '';
      final callerName = event?['callerName'] as String? ?? '';
      final isConnected = event?['connected'] as bool? ?? false;
      final reason = event?['reason'] as String? ?? '';

      log(
        '[CallStateManager] Received callStateChanged: state=$state, num=$number, name=$callerName, connected=$isConnected, reason=$reason',
      );

      // 통화 상태 캐싱 업데이트
      if (state == 'active') {
        _clearCallState();

        // 새 상태 설정
        _cachedCallActive = true;
        _cachedCallNumber = number;
        _cachedCallerName = callerName;
        _cachedCallState = 'active';

        log(
          '[CallStateManager] Call state changed to active, cleared previous state',
        );
      } else if (state == 'incoming') {
        log(
          '[CallStateManager][CRITICAL] 이벤트에서 새 인코밍 콜 감지: $number - 모든 상태 초기화',
        );

        // 차단된 번호인지 확인
        bool isBlocked = false;
        try {
          // 메인 앱에 차단 여부 확인 요청
          _service.invoke('checkIfNumberBlocked', {'phoneNumber': number});

          // 응답 대기 (최대 500ms)
          final completer = Completer<bool>();
          StreamSubscription? subscription;

          subscription = _service.on('responseNumberBlockedStatus').listen((
            event,
          ) {
            final blocked = event?['isBlocked'] as bool? ?? false;
            if (!completer.isCompleted) {
              completer.complete(blocked);
              subscription?.cancel();
            }
          });

          // 짧은 타임아웃 설정 (UI 응답성 유지)
          isBlocked = await completer.future.timeout(
            const Duration(milliseconds: 500),
            onTimeout: () {
              subscription?.cancel();
              return false; // 타임아웃 시 차단되지 않은 것으로 간주
            },
          );
        } catch (e) {
          log('[CallStateManager] 차단 여부 확인 중 오류: $e');
          isBlocked = false;
        }

        // 차단된 번호인 경우 UI 업데이트하지 않음
        if (isBlocked) {
          log('[CallStateManager] 차단된 번호($number) 감지됨. UI 업데이트 건너뜀.');
          return;
        }

        // 철저한 상태 초기화
        _thoroughCallStateReset(number);

        log(
          '[CallStateManager] Call state changed to incoming, cleared previous state',
        );

        // UI에도 초기화 이벤트 전송
        _service.invoke('resetSearchData', {'phoneNumber': number});
      } else if (state == 'ended') {
        _clearCallState();
      }

      // 타이머 로직 호출
      if (state == 'active') {
        // 새 통화인 경우에만 타이머 시작
        if (!isConnected && !_callTimer.isActive) {
          // 새 통화 시작 (아직 연결되지 않음)
          _callTimer.startCallTimer(number, callerName);
        } else if (isConnected && !_callTimer.isActive) {
          // 이미 연결된 통화 - 타이머가 없는 경우에만 시작
          _callTimer.startCallTimer(number, callerName);
        }
      } else if (state == 'ended') {
        _callTimer.stopCallTimer();
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
            title = '통화 중';
            content =
                '$callerName ($number) (${_formatDuration(_callTimer.ongoingSeconds)})';
            payload = 'active:$number';
            break;
          case 'ended':
            title = 'KOLPON';
            content = '';
            payload = 'idle';
            break;
          default:
            log('[CallStateManager] Unknown call state received: $state');
            return;
        }

        // 포그라운드 알림 업데이트
        await _updateForegroundNotification(title, content, payload);

        // UI 스레드로 상태 업데이트 이벤트 보내기
        _updateUiCallState(
          state,
          number,
          '', // 빈 문자열로 변경
          isConnected,
          _callTimer.ongoingSeconds,
          reason,
        );
      }
    });
  }

  Future<void> _setupBroadcastReceiver() async {
    log('[CallStateManager] Setting up BroadcastReceiver for PHONE_STATE...');

    try {
      const String phoneStateAction = "android.intent.action.PHONE_STATE";
      final BroadcastReceiver receiver = BroadcastReceiver(
        names: <String>[phoneStateAction],
      );

      receiver.messages.listen((message) async {
        log(
          '[CallStateManager][BroadcastReceiver] Received broadcast message for $phoneStateAction:',
        );
        final Map<String, dynamic>? intentExtras = message?.data;
        log(
          '[CallStateManager][BroadcastReceiver] Message content (Intent Extras): $intentExtras',
        );

        if (intentExtras != null) {
          final String? state = intentExtras['state'];
          final String? incomingNumber = intentExtras['incoming_number'];
          log(
            '[CallStateManager][BroadcastReceiver] Parsed state: $state, incomingNumber: $incomingNumber',
          );

          // 실시간으로 isDefaultDialer 상태 확인
          final bool isDefaultDialer = await _checkDefaultDialerStatus();

          // RINGING 상태인 경우 인코밍 콜 처리
          if (state == 'RINGING' &&
              incomingNumber != null &&
              incomingNumber.isNotEmpty) {
            log(
              '[CallStateManager][CRITICAL] 새 인코밍 콜 감지: $incomingNumber - 모든 상태 초기화',
            );

            // 차단된 번호인지 확인
            bool isBlocked = false;
            try {
              // 메인 앱에 차단 여부 확인 요청
              _service.invoke('checkIfNumberBlocked', {
                'phoneNumber': incomingNumber,
              });

              // 응답 대기 (최대 500ms)
              final completer = Completer<bool>();
              StreamSubscription? subscription;

              subscription = _service.on('responseNumberBlockedStatus').listen((
                event,
              ) {
                final blocked = event?['isBlocked'] as bool? ?? false;
                if (!completer.isCompleted) {
                  completer.complete(blocked);
                  subscription?.cancel();
                }
              });

              // 짧은 타임아웃 설정 (UI 응답성 유지)
              isBlocked = await completer.future.timeout(
                const Duration(milliseconds: 500),
                onTimeout: () {
                  subscription?.cancel();
                  return false; // 타임아웃 시 차단되지 않은 것으로 간주
                },
              );
            } catch (e) {
              log('[CallStateManager] 차단 여부 확인 중 오류: $e');
              isBlocked = false;
            }

            // 차단된 번호인 경우 UI 업데이트하지 않음
            if (isBlocked) {
              log(
                '[CallStateManager] 차단된 번호($incomingNumber) 감지됨. UI 업데이트 건너뜀.',
              );
              return;
            }

            // 철저한 상태 초기화
            _thoroughCallStateReset(incomingNumber);

            // 연락처 이름 가져오기 시도
            final contactName = await _getContactName(incomingNumber);

            // 수신 전화 노티피케이션 표시
            try {
              log('[CallStateManager] 수신 전화 노티피케이션 표시 시도');
              await LocalNotificationService.showIncomingCallNotification(
                phoneNumber: incomingNumber,
                callerName: contactName, // 가져온 연락처 이름 사용
              );
              log('[CallStateManager] 수신 전화 노티피케이션 표시 성공');

              // 인코밍 콜 알림 갱신 타이머 시작
              _startIncomingCallRefreshTimer(incomingNumber, contactName);
            } catch (e) {
              log('[CallStateManager] 수신 전화 노티피케이션 표시 오류: $e');
            }

            // UI에 바로 상태 전달
            if (_uiInitialized) {
              log(
                '[CallStateManager][BroadcastReceiver] Sending immediate incoming call notification to UI',
              );
              _updateUiCallState(
                'incoming',
                incomingNumber,
                '', // 빈 문자열로 변경
                false,
                0,
                'broadcast_receiver_ringing_reset',
              );
            }
          } else if (state == 'IDLE' && _incomingCallRefreshTimer != null) {
            // RINGING -> IDLE로 변경된 경우 타이머 중지 및 알림 취소
            _stopIncomingCallRefreshTimer();

            try {
              await LocalNotificationService.cancelNotification(
                CALL_STATUS_NOTIFICATION_ID,
              );
              log('[CallStateManager] 수신 전화 노티피케이션 취소 성공');
            } catch (e) {
              log('[CallStateManager] 수신 전화 노티피케이션 취소 오류: $e');
            }
          }
        }
      });

      await receiver.start();
    } catch (e) {
      log(
        '[CallStateManager] Error setting up or starting BroadcastReceiver: $e',
      );
    }
  }

  void _startCallStateCheckTimer() {
    // 이미 실행 중인 타이머가 있으면 취소
    _callStateCheckTimer?.cancel();

    // 첫 번째 체크 플래그 설정
    _isFirstCheck = true;

    // 1초마다 통화 상태 체크
    _callStateCheckTimer = Timer.periodic(const Duration(seconds: 1), (
      timer,
    ) async {
      try {
        // 로그인 상태 확인 먼저 수행
        bool isLoggedIn = false;
        try {
          // 로그인 상태 확인 요청 전송
          _service.invoke('checkLoginStatus');

          // 응답 대기
          final completer = Completer<bool>();
          StreamSubscription? subscription;

          subscription = _service.on('responseLoginStatus').listen((event) {
            final loggedIn = event?['isLoggedIn'] as bool? ?? false;
            if (!completer.isCompleted) {
              completer.complete(loggedIn);
              subscription?.cancel();
            }
          });

          // 짧은 타임아웃 설정
          isLoggedIn = await completer.future.timeout(
            const Duration(milliseconds: 500),
            onTimeout: () {
              subscription?.cancel();
              return false; // 타임아웃 시 로그인되지 않은 것으로 간주
            },
          );
        } catch (e) {
          log('[CallStateManager] 로그인 상태 확인 중 오류: $e');
          isLoggedIn = false;
        }

        // 로그인되지 않은 경우 통화 상태 체크 건너뛰기
        if (!isLoggedIn) {
          // log('[CallStateManager] 로그인되지 않음. 통화 상태 체크 건너뛰기.');
          return;
        }

        // 네이티브 통화 상태 확인
        final nativeCallState = await _getCurrentCallStateFromNative();
        if (nativeCallState == null) return;

        final String state = nativeCallState['state'] as String? ?? 'IDLE';
        final String number = nativeCallState['number'] as String? ?? '';

        // 상태 변경 감지 (첫 체크 또는 상태 변경 시에만 처리)
        bool stateChanged =
            state != _lastCheckedCallState || number != _lastCheckedCallNumber;

        if (_isFirstCheck || stateChanged) {
          // 상태 업데이트
          _lastCheckedCallState = state;
          _lastCheckedCallNumber = number;

          // 인코밍 전화 상태 보호: 앱이 방금 시작되었고, 인코밍 상태가 캐싱되어 있을 때
          // ACTIVE로 너무 빨리 변경되는 것을 방지
          final bool isJustStarted = _isFirstCheck;
          final bool hasCachedIncoming =
              _cachedCallState == 'incoming' &&
              _cachedCallActive &&
              _cachedCallNumber.isNotEmpty;
          final bool isIncomingRecent =
              DateTime.now().millisecondsSinceEpoch - _cachedIncomingTimestamp <
              2000;

          if (hasCachedIncoming &&
              isJustStarted &&
              isIncomingRecent &&
              state.toUpperCase() == 'ACTIVE') {
            log(
              '[CallStateManager][CallStateCheck] 방금 시작된 앱에서 인코밍 콜 보호: ACTIVE 상태 무시, INCOMING 유지',
            );
            return; // 인코밍 상태 보호를 위해 추가 처리 중단
          }

          if (state.toUpperCase() == 'ACTIVE' ||
              state.toUpperCase() == 'DIALING') {
            log(
              '[CallStateManager][CallStateCheck] Active call detected: $number',
            );

            // 기존 상태 완전히 초기화
            _clearCallState();

            // 새 통화 중 상태 캐싱
            _cachedCallActive = true;
            _cachedCallNumber = number;
            _cachedCallState = 'active';

            log(
              '[CallStateManager][CallStateCheck] Previous state cleared, new active state cached',
            );

            // 타이머가 실행 중이 아닐 때만 시작 (통화 시간 리셋 방지)
            if (!_callTimer.isActive) {
              log('[CallStateManager][CallStateCheck] Starting call timer');
              _callTimer.startCallTimer(number, '');
            }
          } else if (state.toUpperCase() == 'RINGING') {
            log(
              '[CallStateManager][CRITICAL] 타이머에서 새 인코밍 콜 감지: $number - 모든 상태 초기화',
            );

            // 차단된 번호인지 확인
            bool isBlocked = false;
            try {
              // 메인 앱에 차단 여부 확인 요청
              _service.invoke('checkIfNumberBlocked', {'phoneNumber': number});

              // 응답 대기 (최대 500ms)
              final completer = Completer<bool>();
              StreamSubscription? subscription;

              subscription = _service.on('responseNumberBlockedStatus').listen((
                event,
              ) {
                final blocked = event?['isBlocked'] as bool? ?? false;
                if (!completer.isCompleted) {
                  completer.complete(blocked);
                  subscription?.cancel();
                }
              });

              // 짧은 타임아웃 설정 (UI 응답성 유지)
              isBlocked = await completer.future.timeout(
                const Duration(milliseconds: 500),
                onTimeout: () {
                  subscription?.cancel();
                  return false; // 타임아웃 시 차단되지 않은 것으로 간주
                },
              );
            } catch (e) {
              log('[CallStateManager] 차단 여부 확인 중 오류: $e');
              isBlocked = false;
            }

            // 차단된 번호인 경우 UI 업데이트하지 않음
            if (isBlocked) {
              log('[CallStateManager] 차단된 번호($number) 감지됨. UI 업데이트 건너뜀.');
              return;
            }

            // 철저한 상태 초기화
            _thoroughCallStateReset(number);

            // 수신 전화 노티피케이션 표시 (새로 추가된 코드)
            try {
              // 연락처 이름 가져오기 시도 (이미 인코밍 타이머가 실행 중인지 확인)
              if (_incomingCallRefreshTimer == null) {
                final contactName = await _getContactName(number);
                log('[CallStateManager] 타이머에서 수신 전화 노티피케이션 표시 시도');
                await LocalNotificationService.showIncomingCallNotification(
                  phoneNumber: number,
                  callerName: contactName,
                );
                log('[CallStateManager] 타이머에서 수신 전화 노티피케이션 표시 성공');

                // 인코밍 콜 노티피케이션 갱신 타이머 시작
                _startIncomingCallRefreshTimer(number, contactName);
              }
            } catch (e) {
              log('[CallStateManager] 타이머에서 수신 전화 노티피케이션 표시 오류: $e');
            }

            // UI에 인코밍 상태 알림
            if (_uiInitialized) {
              _updateUiCallState(
                'incoming',
                number,
                '', // 빈 문자열로 변경
                false,
                0,
                'periodic_check_reset',
              );

              // 로그에 인코밍 상태임을 명확히 표시
              log(
                '[CallStateManager][CallStateCheck] UI updated with INCOMING state, not moving to ACTIVE',
              );
            }
          } else if (state.toUpperCase() == 'IDLE' && _cachedCallActive) {
            log(
              '[CallStateManager][CallStateCheck] Call ended (state: $_cachedCallState), stopping timer',
            );

            // 통화 종료 상태 캐싱
            _clearCallState();

            // 타이머 중지
            _callTimer.stopCallTimer();

            // 수신 전화 노티피케이션 취소
            try {
              await LocalNotificationService.cancelNotification(
                CALL_STATUS_NOTIFICATION_ID,
              );
              log('[CallStateManager] 수신 전화 노티피케이션 취소 성공');
            } catch (e) {
              log('[CallStateManager] 수신 전화 노티피케이션 취소 오류: $e');
            }

            // UI 업데이트 메시지 전송
            if (_uiInitialized) {
              _updateUiCallState(
                'ended',
                _lastCheckedCallNumber,
                '', // 빈 문자열로 변경
                false,
                0,
                'periodic_check_ended',
              );

              // 포그라운드 알림 업데이트
              await _updateForegroundNotification('KOLPON', '', 'idle');
            }
          }
        }

        // 첫 번째 체크 완료 후 플래그 해제
        if (_isFirstCheck) {
          _isFirstCheck = false;
        }
      } catch (e) {
        log('[CallStateManager][CallStateCheck] Error checking call state: $e');
      }
    });

    log(
      '[CallStateManager] Call state check timer started (1-second intervals)',
    );
  }

  Future<Map<String, dynamic>?> _getCurrentCallStateFromNative() async {
    _service.invoke('requestCurrentCallStateFromAppControllerForTimer');
    final Completer<Map<String, dynamic>?> completer = Completer();
    StreamSubscription? subscription;

    subscription = _service
        .on('responseCurrentCallStateToBackgroundForTimer')
        .listen((event) {
          if (!completer.isCompleted) {
            completer.complete(event);
            subscription?.cancel();
          }
        });

    try {
      return await completer.future.timeout(const Duration(milliseconds: 1500));
    } catch (e) {
      log('[CallStateManager] Timeout or error waiting for native state: $e');
      subscription?.cancel();
      return null;
    }
  }

  Future<bool> _checkDefaultDialerStatus() async {
    _service.invoke('requestDefaultDialerStatus');

    final Completer<bool> completer = Completer<bool>();
    StreamSubscription? subscription;

    subscription = _service.on('respondDefaultDialerStatus').listen((event) {
      final bool isDefault = event?['isDefault'] as bool? ?? false;
      log('[CallStateManager] Received respondDefaultDialerStatus: $isDefault');
      if (!completer.isCompleted) {
        completer.complete(isDefault);
        subscription?.cancel();
      }
    });

    Future.delayed(const Duration(seconds: 2), () {
      if (!completer.isCompleted) {
        log(
          '[CallStateManager] Timeout waiting for respondDefaultDialerStatus.',
        );
        completer.complete(false);
        subscription?.cancel();
      }
    });

    return await completer.future;
  }

  Future<void> _updateForegroundNotification(
    String title,
    String content,
    String payload,
  ) async {
    if (_service is AndroidServiceInstance) {
      final androidService = _service as AndroidServiceInstance;
      if (await androidService.isForegroundService()) {
        _notifications.show(
          FOREGROUND_SERVICE_NOTIFICATION_ID,
          title,
          content,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              FOREGROUND_SERVICE_CHANNEL_ID,
              'KOLPON 서비스 상태',
              icon: 'app_icon_main',
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
  }

  void _updateUiCallState(
    String state,
    String number,
    String callerName,
    bool connected,
    int duration,
    String reason,
  ) async {
    // active 상태인 경우에만 네이티브에서 최신 정보 확인
    if (state == 'active') {
      try {
        final nativeState = await _getCurrentCallStateFromNative();
        if (nativeState != null) {
          final activeState = nativeState['active_state'] as String? ?? 'IDLE';
          final activeNumber = nativeState['active_number'] as String?;
          
          // 네이티브에서 활성 통화 번호가 있으면 그것을 사용
          if (activeState == 'ACTIVE' && activeNumber != null && activeNumber.isNotEmpty) {
            if (number != activeNumber) {
              log('[CallStateManager] Correcting number before UI update: $number -> $activeNumber');
              number = activeNumber;
            }
          }
        }
      } catch (e) {
        log('[CallStateManager] Error checking native call state before UI update: $e');
      }
    }
    
    // UI 업데이트 메시지 전송
    _service.invoke('updateUiCallState', {
      'state': state,
      'number': number,
      'callerName': callerName,
      'connected': connected,
      'duration': duration,
      'reason': reason,
    });
  }

  void _clearCallState() {
    _cachedCallActive = false;
    _cachedCallNumber = '';
    _cachedCallerName = '';
    _cachedCallState = 'idle';
    _cachedIncomingTimestamp = 0;
  }

  String _formatDuration(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return "$minutes:$secs";
  }

  Future<void> checkInitialCallState() async {
    try {
      final callState = await _getCurrentCallStateFromNative();
      if (callState != null) {
        final String state = callState['state'] as String? ?? 'IDLE';
        final String number = callState['number'] as String? ?? '';

        log(
          '[CallStateManager] Initial call state check: state=$state, number=$number',
        );

        // 통화 중인 경우 상태 캐싱
        if (state.toUpperCase() == 'ACTIVE' ||
            state.toUpperCase() == 'DIALING') {
          _cachedCallActive = true;
          _cachedCallNumber = number;
          _cachedCallerName = '';

          log('[CallStateManager] Cached active call state: number=$number');
        }
      }
    } catch (e) {
      log('[CallStateManager] Error checking initial call state: $e');
    }
  }

  void _thoroughCallStateReset(String newNumber) {
    log('[CallStateManager][CRITICAL] 철저한 상태 초기화 시작: $newNumber');

    // 기존 상태 변수 초기화
    _cachedCallActive = false;
    _cachedCallNumber = '';
    _cachedCallerName = '';
    _cachedCallState = 'idle';
    _cachedIncomingTimestamp = 0;

    // 명시적으로 콜 타이머 중지
    _callTimer.stopCallTimer();

    // UI에도 초기화 요청
    _service.invoke('resetSearchData', {});

    // 이후 새 인코밍 상태 설정
    _cachedCallActive = true;
    _cachedCallNumber = newNumber;
    _cachedCallState = 'incoming';
    _cachedIncomingTimestamp = DateTime.now().millisecondsSinceEpoch;

    log('[CallStateManager][CRITICAL] 상태 초기화 완료 후 설정: $_cachedCallNumber');
  }

  // 인코밍 콜 알림 주기적으로 갱신하는 타이머 시작
  void _startIncomingCallRefreshTimer(String phoneNumber, String callerName) {
    // 이미 실행 중인 타이머가 있으면 취소
    _stopIncomingCallRefreshTimer();

    // 카운터 초기화
    _incomingCallNotificationCount = 1; // 이미 한 번 표시했으므로 1부터 시작

    // 3초마다 알림 갱신 (20번까지)
    _incomingCallRefreshTimer = Timer.periodic(const Duration(seconds: 3), (
      timer,
    ) async {
      // 최대 20회까지만 알림 표시 (약 60초)
      if (_incomingCallNotificationCount >= 20) {
        _stopIncomingCallRefreshTimer();
        return;
      }

      // 연락처 이름이 없으면 다시 가져오기 시도 (매 2회마다)
      String updatedName = callerName;
      if (callerName.isEmpty && _incomingCallNotificationCount % 2 == 0) {
        updatedName = await _getContactName(phoneNumber);
        if (updatedName.isNotEmpty) {
          callerName = updatedName; // 이름을 가져왔으면 업데이트
        }
      }

      try {
        await LocalNotificationService.showIncomingCallNotification(
          phoneNumber: phoneNumber,
          callerName: updatedName,
        );
        log(
          '[CallStateManager] 수신 전화 노티피케이션 갱신 성공 (${_incomingCallNotificationCount}/20)',
        );
        _incomingCallNotificationCount++;
      } catch (e) {
        log('[CallStateManager] 수신 전화 노티피케이션 갱신 오류: $e');
      }

      // 현재 전화 상태 확인하여 RINGING이 아니면 타이머 정지
      try {
        final callState = await _getCurrentCallStateFromNative();
        if (callState != null) {
          final String state = callState['state'] as String? ?? 'IDLE';
          if (state.toUpperCase() != 'RINGING') {
            log('[CallStateManager] RINGING 상태가 아님. 갱신 타이머 정지');
            _stopIncomingCallRefreshTimer();

            // 알림 취소
            await LocalNotificationService.cancelNotification(
              CALL_STATUS_NOTIFICATION_ID,
            );
          }
        }
      } catch (e) {
        log('[CallStateManager] 통화 상태 확인 중 오류: $e');
      }
    });

    log('[CallStateManager] 수신 전화 노티피케이션 갱신 타이머 시작');
  }

  // 인코밍 콜 알림 갱신 타이머 정지
  void _stopIncomingCallRefreshTimer() {
    if (_incomingCallRefreshTimer?.isActive ?? false) {
      _incomingCallRefreshTimer!.cancel();
      _incomingCallRefreshTimer = null;
      log('[CallStateManager] 수신 전화 노티피케이션 갱신 타이머 정지');
    }
  }

  // 연락처 이름 조회 (백그라운드에서)
  Future<String> _getContactName(String phoneNumber) async {
    try {
      // 메인 앱에 연락처 조회 요청
      _service.invoke('requestContactName', {'phoneNumber': phoneNumber});

      // 응답 기다리기
      final completer = Completer<String>();
      StreamSubscription? subscription;

      subscription = _service.on('responseContactName').listen((event) {
        final name = event?['contactName'] as String? ?? '';
        if (!completer.isCompleted) {
          completer.complete(name);
          subscription?.cancel();
        }
      });

      // 2초 타임아웃 설정
      return await completer.future.timeout(
        const Duration(seconds: 2),
        onTimeout: () {
          subscription?.cancel();
          return '';
        },
      );
    } catch (e) {
      log('[CallStateManager] Error getting contact name: $e');
      return '';
    }
  }
}
