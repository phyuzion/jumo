import 'dart:async';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:phone_state/phone_state.dart';
import 'package:mobile/providers/call_state_provider.dart';
import 'package:mobile/controllers/call_log_controller.dart';
import 'package:mobile/controllers/contacts_controller.dart';
import 'package:mobile/controllers/blocked_numbers_controller.dart';
import 'package:mobile/services/native_default_dialer_methods.dart';
import 'package:mobile/services/native_methods.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:mobile/utils/constants.dart';
import 'package:mobile/controllers/app_controller.dart';
import 'package:mobile/utils/app_event_bus.dart';
import 'package:mobile/services/local_notification_service.dart';

class PhoneStateController with WidgetsBindingObserver {
  final GlobalKey<NavigatorState> navigatorKey;
  final CallLogController callLogController;
  final ContactsController contactsController;
  final BlockedNumbersController _blockedNumbersController;
  final AppController appController;

  PhoneStateController(
    this.navigatorKey,
    this.callLogController,
    this.contactsController,
    this._blockedNumbersController,
    this.appController,
  ) {
    WidgetsBinding.instance.addObserver(this);
    log('[PhoneStateController.constructor] Instance created.');

    final service = FlutterBackgroundService();
    _searchResetSubscription = service.on('requestSearchDataReset').listen((
      event,
    ) {
      log('[PhoneStateController][CRITICAL] 검색 데이터 리셋 요청 수신');
      appEventBus.fire(CallSearchResetEvent(''));
    });

    // 정기적인 통화 상태 체크 타이머 시작
    _startCallStateCheckTimer();
  }

  StreamSubscription<PhoneState>? _phoneStateSubscription;
  StreamSubscription? _searchResetSubscription;

  String? _lastProcessedNumber;
  PhoneStateStatus? _lastProcessedStatus;
  DateTime? _lastProcessedTime;
  String? _rejectedNumber;

  // 인코밍 콜 노티피케이션 주기적 갱신을 위한 타이머
  Timer? _incomingCallRefreshTimer;
  int _incomingCallNotificationCount = 0;
  String _currentIncomingNumber = '';
  String _currentIncomingCallerName = '';

  // 통화 상태 정기 체크 타이머 추가
  Timer? _callStateCheckTimer;
  DateTime? _lastCallStateCheckTime;

  void startListening() {
    _phoneStateSubscription?.cancel();
    _phoneStateSubscription = PhoneState.stream.listen((event) async {
      // log(
      //   '[PhoneStateController][Stream] Received event: ${event.status}, Number: ${event.number}',
      // );
      final isDef = await NativeDefaultDialerMethods.isDefaultDialer();
      if (!isDef) {
        await _handlePhoneStateEvent(event.status, event.number);
      } else {
        // log(
        //   '[PhoneStateController][Stream] Default dialer is active, ignoring event from phone_state package.',
        // );
      }
    });
    log(
      '[PhoneStateController.startListening] Listening to phone state stream.',
    );

    // 통화 상태 체크 타이머가 실행 중이 아니면 시작
    if (_callStateCheckTimer == null || !_callStateCheckTimer!.isActive) {
      _startCallStateCheckTimer();
    }
  }

  void stopListening() {
    _phoneStateSubscription?.cancel();
    _phoneStateSubscription = null;
    _searchResetSubscription?.cancel();
    _searchResetSubscription = null;
    _stopIncomingCallRefreshTimer(); // 인코밍 콜 타이머 정리

    // 통화 상태 체크 타이머도 정리
    if (_callStateCheckTimer?.isActive ?? false) {
      _callStateCheckTimer!.cancel();
      _callStateCheckTimer = null;
      log('[PhoneStateController] 정기 통화 상태 체크 타이머 정지');
    }

    log('[PhoneStateController] Stopped listening to phone state stream.');
  }

  // 인코밍 콜 노티피케이션 갱신 타이머 시작
  void _startIncomingCallRefreshTimer(String phoneNumber, String callerName) {
    // 이미 실행 중인 타이머가 있으면 취소
    _stopIncomingCallRefreshTimer();

    // 현재 인코밍 정보 저장
    _currentIncomingNumber = phoneNumber;
    _currentIncomingCallerName = callerName;

    // 카운터 초기화
    _incomingCallNotificationCount = 1; // 이미 한 번 표시했으므로 1부터 시작

    // 3초마다 알림 갱신 (최대 20번, 약 60초)
    _incomingCallRefreshTimer = Timer.periodic(const Duration(seconds: 3), (
      timer,
    ) async {
      // 최대 20회까지만 알림 표시
      if (_incomingCallNotificationCount >= 20) {
        _stopIncomingCallRefreshTimer();
        return;
      }

      // 연락처 이름이 없으면 매 2회마다 다시 가져오기 시도
      String updatedName = _currentIncomingCallerName;
      if (_currentIncomingCallerName.isEmpty &&
          _incomingCallNotificationCount % 2 == 0) {
        updatedName = await contactsController.getContactName(
          _currentIncomingNumber,
        );
        if (updatedName.isNotEmpty) {
          _currentIncomingCallerName = updatedName; // 이름 업데이트
        }
      }

      try {
        await LocalNotificationService.showIncomingCallNotification(
          phoneNumber: _currentIncomingNumber,
          callerName: updatedName,
        );
        log(
          '[PhoneStateController] 수신 전화 노티피케이션 갱신 성공 (${_incomingCallNotificationCount}/20)',
        );
        _incomingCallNotificationCount++;
      } catch (e) {
        log('[PhoneStateController] 수신 전화 노티피케이션 갱신 오류: $e');
      }
    });

    log('[PhoneStateController] 수신 전화 노티피케이션 갱신 타이머 시작');
  }

  // 인코밍 콜 노티피케이션 갱신 타이머 정지
  void _stopIncomingCallRefreshTimer() {
    if (_incomingCallRefreshTimer?.isActive ?? false) {
      _incomingCallRefreshTimer!.cancel();
      _incomingCallRefreshTimer = null;
      log('[PhoneStateController] 수신 전화 노티피케이션 갱신 타이머 정지');
    }
    _currentIncomingNumber = '';
    _currentIncomingCallerName = '';
    _incomingCallNotificationCount = 0;
  }

  Future<void> handleNativeEvent(
    String method,
    dynamic args,
    bool isDefault,
  ) async {
    log(
      '[PhoneStateController][Native] Received event: $method, IsDefault: $isDefault',
    );
    String number = '';
    bool connected = false;
    String reason = '';
    PhoneStateStatus status = PhoneStateStatus.NOTHING;

    if (args != null) {
      if (args is Map) {
        number = args['number'] as String? ?? '';
        connected = args['connected'] as bool? ?? false;
        reason = args['reason'] as String? ?? '';
      } else if (args is String) {
        number = args;
      }
    }

    switch (method) {
      case 'onIncomingNumber':
        status = PhoneStateStatus.CALL_INCOMING;

        // 먼저 차단 확인을 수행하고, 차단된 번호인 경우 이벤트를 발생시키지 않고 바로 차단하도록 수정
        if (number.isNotEmpty) {
          final normalizedNumber = normalizePhone(number);

          // 차단된 번호인지 확인
          bool isBlocked = false;
          try {
            isBlocked = await _blockedNumbersController.isNumberBlockedAsync(
              normalizedNumber,
              addHistory: true,
            );
          } catch (e) {
            log('[PhoneStateController] Error checking block status: $e');
          }

          // 차단된 번호인 경우 거절하고 종료
          if (isBlocked) {
            log(
              '[PhoneStateController] Call from $normalizedNumber is BLOCKED. Rejecting immediately...',
            );
            _rejectedNumber = normalizedNumber;
            try {
              await NativeMethods.rejectCall();
              log('[PhoneStateController] Reject call command sent.');
              return; // 차단된 번호이므로 여기서 처리 종료
            } catch (e) {
              log('[PhoneStateController] Error rejecting call: $e');
            }
            return;
          }

          // 차단되지 않은 번호만 데이터 초기화 요청
          log(
            '[PhoneStateController][CRITICAL] 네이티브에서 인코밍 콜 감지: $normalizedNumber - 데이터 초기화 요청',
          );
          appEventBus.fire(CallSearchResetEvent(normalizedNumber));
        }
        break;
      case 'onCall':
        status =
            connected
                ? PhoneStateStatus.CALL_STARTED
                : PhoneStateStatus.CALL_STARTED;
        // 통화가 시작되면 수신 전화 노티피케이션 취소 및 타이머 정지
        _stopIncomingCallRefreshTimer();
        try {
          await LocalNotificationService.cancelNotification(
            9876,
          ); // INCOMING_CALL_NOTIFICATION_ID
          log('[PhoneStateController] 통화 시작으로 수신 전화 노티피케이션 취소');
        } catch (e) {
          log('[PhoneStateController] 수신 전화 노티피케이션 취소 오류: $e');
        }
        break;
      case 'onCallEnded':
        status = PhoneStateStatus.CALL_ENDED;
        // 통화 종료 시 남은 노티피케이션 및 타이머 정리
        _stopIncomingCallRefreshTimer();
        try {
          await LocalNotificationService.cancelNotification(
            9876,
          ); // INCOMING_CALL_NOTIFICATION_ID
          log('[PhoneStateController] 통화 종료로 수신 전화 노티피케이션 취소');
        } catch (e) {
          log('[PhoneStateController] 수신 전화 노티피케이션 취소 오류: $e');
        }
        break;
    }

    await _handlePhoneStateEvent(
      status,
      number,
      isConnected: connected,
      reason: reason,
    );
  }

  bool _isDuplicateEvent(String? number, PhoneStateStatus? status) {
    final now = DateTime.now();
    // log('[_isDuplicateEvent] Checking: number=$number, status=$status');
    // log(
    //   '[_isDuplicateEvent] Last processed: number=$_lastProcessedNumber, status=$_lastProcessedStatus, time=$_lastProcessedTime',
    // );

    bool isDup = false;
    if (number == _lastProcessedNumber &&
        status == _lastProcessedStatus &&
        _lastProcessedTime != null &&
        now.difference(_lastProcessedTime!).inSeconds < 2) {
      isDup = true;
    }

    if (!isDup) {
      _lastProcessedNumber = number;
      _lastProcessedStatus = status;
      _lastProcessedTime = now;
      // log('[_isDuplicateEvent] Updated last processed info.');
    } else {
      log(
        '[_isDuplicateEvent] Duplicate event detected and ignored: num=$number, status=$status',
      );
    }
    return isDup;
  }

  Future<void> _handlePhoneStateEvent(
    PhoneStateStatus status,
    String? number, {
    bool isConnected = false,
    String? reason,
  }) async {
    if (_isDuplicateEvent(number, status)) {
      // log(
      //   '[_handlePhoneStateEvent] Duplicate event ignored. Number: $number, Status: $status',
      // );
      return;
    }
    log(
      '[_handlePhoneStateEvent] Processing event. Number: $number, Status: $status, Reason: $reason',
    );

    String? normalizedNumber;
    if (number != null && number.isNotEmpty) {
      normalizedNumber = normalizePhone(number);
    } else {
      if (status == PhoneStateStatus.CALL_ENDED && _rejectedNumber != null) {
        // log(
        //   '[_handlePhoneStateEvent] Ignoring CALL_ENDED event with null number, possibly after rejection.',
        // );
        _rejectedNumber = null;
        return;
      }
      if (status == PhoneStateStatus.NOTHING ||
          status == PhoneStateStatus.CALL_ENDED) {
        // log(
        //   '[_handlePhoneStateEvent] Number is null or empty for status $status, processing as general state change.',
        // );
        if (status == PhoneStateStatus.CALL_ENDED) {
          // log('[_handlePhoneStateEvent] Call ended (null number). Adding 1.5s delay before refreshing call logs.');
          await Future.delayed(const Duration(milliseconds: 1500));
          bool callLogChanged = await callLogController.refreshCallLogs();
          if (callLogChanged) {
            // log(
            //   '[_handlePhoneStateEvent] Call logs changed (null number end), firing CallLogUpdatedEvent.',
            // );
            appEventBus.fire(CallLogUpdatedEvent());
          }
        }
        return;
      }
      log(
        '[_handlePhoneStateEvent] Number is null for critical state $status. Ignoring.',
      );
      return;
    }

    if (status == PhoneStateStatus.CALL_ENDED &&
        _rejectedNumber == normalizedNumber) {
      log(
        '[_handlePhoneStateEvent] Ignoring CALL_ENDED for recently REJECTED: $normalizedNumber',
      );
      _rejectedNumber = null;
      return;
    }
    if (status != PhoneStateStatus.CALL_ENDED) {
      _rejectedNumber = null;
    }

    if (status == PhoneStateStatus.CALL_INCOMING) {
      // 차단 확인 로직은 handleNativeEvent로 이동, 여기서는 이미 차단 확인이 끝난 번호만 처리
      log('[PhoneStateController] Call from $normalizedNumber is NOT blocked.');

      // 수신 전화 노티피케이션 표시 및 타이머 시작
      try {
        log('[PhoneStateController] 수신 전화 노티피케이션 표시 시도: $normalizedNumber');
        // 연락처 이름 가져오기
        String callerName = await contactsController.getContactName(
          normalizedNumber!,
        );
        await LocalNotificationService.showIncomingCallNotification(
          phoneNumber: normalizedNumber,
          callerName: callerName,
        );
        log('[PhoneStateController] 수신 전화 노티피케이션 표시 성공');

        // 노티피케이션 갱신 타이머 시작
        _startIncomingCallRefreshTimer(normalizedNumber, callerName);
      } catch (e) {
        log('[PhoneStateController] 수신 전화 노티피케이션 표시 오류: $e');
      }
    } else if (status == PhoneStateStatus.CALL_STARTED) {
      // 통화 시작 시 인코밍 콜 노티피케이션 취소 및 타이머 정지
      _stopIncomingCallRefreshTimer();
      try {
        await LocalNotificationService.cancelNotification(9876);
        log('[PhoneStateController] 통화 시작으로 수신 전화 노티피케이션 취소');
      } catch (e) {
        log('[PhoneStateController] 수신 전화 노티피케이션 취소 오류: $e');
      }
    }

    final String callerName = '';

    CallState newState = CallState.idle;
    String stateMethod = '';

    switch (status) {
      case PhoneStateStatus.NOTHING:
        newState = CallState.idle;
        stateMethod = 'onCallEnded';
        // NOTHING 상태로 변경 시에도 인코밍 콜 정리
        _stopIncomingCallRefreshTimer();
        try {
          await LocalNotificationService.cancelNotification(9876);
          log('[PhoneStateController] 상태 초기화로 수신 전화 노티피케이션 취소');
        } catch (e) {
          log('[PhoneStateController] 수신 전화 노티피케이션 취소 오류: $e');
        }
        break;
      case PhoneStateStatus.CALL_INCOMING:
        newState = CallState.incoming;
        stateMethod = 'onIncomingNumber';
        break;
      case PhoneStateStatus.CALL_STARTED:
        newState = CallState.active;
        stateMethod = 'onCall';
        break;
      case PhoneStateStatus.CALL_ENDED:
        newState = CallState.ended;
        stateMethod = 'onCallEnded';
        // 통화 종료 시 수신 전화 노티피케이션 취소
        _stopIncomingCallRefreshTimer();
        try {
          await LocalNotificationService.cancelNotification(
            9876,
          ); // INCOMING_CALL_NOTIFICATION_ID
          log('[PhoneStateController] 통화 종료로 수신 전화 노티피케이션 취소');
        } catch (e) {
          log('[PhoneStateController] 수신 전화 노티피케이션 취소 오류: $e');
        }
        break;
    }

    if (stateMethod.isNotEmpty) {
      notifyServiceCallState(
        stateMethod,
        normalizedNumber!,
        callerName,
        connected: isConnected,
        reason: reason ?? (newState == CallState.ended ? 'missed' : ''),
      );
    }

    if (status == PhoneStateStatus.CALL_ENDED) {
      // log('[_handlePhoneStateEvent] Call ended. Adding 1.5s delay before refreshing call logs.');
      await Future.delayed(const Duration(milliseconds: 1500));
      bool callLogChanged = await callLogController.refreshCallLogs();
      if (callLogChanged) {
        log(
          '[_handlePhoneStateEvent] Call logs changed, firing CallLogUpdatedEvent.',
        );
        appEventBus.fire(CallLogUpdatedEvent());
      }
    }
  }

  void notifyServiceCallState(
    String stateMethod,
    String number,
    String callerName, {
    bool? connected,
    String? reason,
  }) {
    // log(
    //   '[PhoneStateController][notifyServiceCallState] Method called: stateMethod=$stateMethod, number=$number, name=$callerName, connected=$connected, reason=$reason',
    // );

    final service = FlutterBackgroundService();
    String state;
    bool isConnectedValue = connected ?? false;
    String reasonValue = reason ?? '';

    switch (stateMethod) {
      case 'onIncomingNumber':
        state = 'incoming';
        break;
      case 'onCall':
        state = 'active';
        break;
      case 'onCallEnded':
        state = 'ended';
        break;
      default:
        state = 'unknown';
    }

    if (state == 'unknown') {
      // log(
      //   '[PhoneStateController][notifyServiceCallState] Unknown stateMethod $stateMethod, not invoking service.',
      // );
      return;
    }

    final payload = {
      'state': state,
      'number': number,
      'callerName': callerName,
      'connected': isConnectedValue,
      'reason': reasonValue,
    };

    // log(
    //   '[PhoneStateController][notifyServiceCallState] Invoking service with callStateChanged. Payload: $payload',
    // );
    try {
      service.invoke('callStateChanged', payload);
      // log(
      //   '[PhoneStateController][notifyServiceCallState] Successfully invoked service with callStateChanged.',
      // );
    } catch (e) {
      log(
        '[PhoneStateController][notifyServiceCallState] Error invoking service: $e',
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // log('[PhoneStateController.didChangeAppLifecycleState] State: $state');
    if (state == AppLifecycleState.resumed) {
      syncInitialCallState();
    }
  }

  Future<void> syncInitialCallState() async {
    log('[PhoneStateController] Syncing initial call state...');
    try {
      // 현재 통화 상태를 네이티브 측에서 가져옴
      final callDetails = await NativeMethods.getCurrentCallState();
      log(
        '[PhoneStateController] Initial call state from native: $callDetails',
      );

      final state = callDetails['state'] as String? ?? 'IDLE';
      final number = callDetails['number'] as String?;

      // 전화번호가 없거나 IDLE 상태면 처리할 필요 없음
      if (number == null || number.isEmpty || state == 'IDLE') {
        log(
          '[PhoneStateController] No active call detected in initial state check.',
        );
        return;
      }

      // 통화 상태에 따라 적절한 이벤트 발생
      final normalizedNumber = normalizePhone(number);
      String callerName = '';

      // 전화 상태에 따른 처리
      switch (state) {
        case 'RINGING':
          log(
            '[PhoneStateController] Detected RINGING call on app start/resume: $normalizedNumber',
          );

          // 차단된 번호인지 확인 (이 부분이 먼저 실행되도록 수정)
          bool isBlocked = false;
          try {
            isBlocked = await _blockedNumbersController.isNumberBlockedAsync(
              normalizedNumber,
              addHistory: false, // 이미 진행 중인 전화이므로 기록 남기지 않음
            );
          } catch (e) {
            log('[PhoneStateController] Error checking block status: $e');
          }

          if (isBlocked) {
            log(
              '[PhoneStateController] Call from $normalizedNumber is BLOCKED.',
            );
            try {
              await NativeMethods.rejectCall();
            } catch (e) {
              log('[PhoneStateController] Error rejecting call: $e');
            }
            return; // 차단된 번호라면 여기서 처리 종료
          }

          // 차단되지 않은 번호인 경우에만 발신자 정보 초기화 이벤트 트리거
          appEventBus.fire(CallSearchResetEvent(normalizedNumber));

          // 수신 전화 노티피케이션 표시 및 타이머 시작
          try {
            log(
              '[PhoneStateController] 앱 시작/재개 시 수신 전화 노티피케이션 표시 시도: $normalizedNumber',
            );
            // 연락처 이름 가져오기
            callerName = await contactsController.getContactName(
              normalizedNumber,
            );
            await LocalNotificationService.showIncomingCallNotification(
              phoneNumber: normalizedNumber,
              callerName: callerName,
            );
            log('[PhoneStateController] 수신 전화 노티피케이션 표시 성공');

            // 노티피케이션 갱신 타이머 시작
            _startIncomingCallRefreshTimer(normalizedNumber, callerName);
          } catch (e) {
            log('[PhoneStateController] 수신 전화 노티피케이션 표시 오류: $e');
          }

          // 통화 상태 알림을 백그라운드 서비스에 전송
          notifyServiceCallState(
            'onIncomingNumber',
            normalizedNumber,
            callerName,
          );
          break;

        case 'ACTIVE':
        case 'DIALING':
          log(
            '[PhoneStateController] Detected ACTIVE/DIALING call on app start/resume: $normalizedNumber',
          );

          // 발신자 정보 초기화 이벤트 트리거
          appEventBus.fire(CallSearchResetEvent(normalizedNumber));

          // 통화 중이므로 인코밍 콜 노티피케이션 취소 및 타이머 정지
          _stopIncomingCallRefreshTimer();
          try {
            await LocalNotificationService.cancelNotification(9876);
            log('[PhoneStateController] 활성 통화 상태에서 수신 전화 노티피케이션 취소');
          } catch (e) {
            log('[PhoneStateController] 수신 전화 노티피케이션 취소 오류: $e');
          }

          // 통화 상태 알림을 백그라운드 서비스에 전송
          notifyServiceCallState(
            'onCall',
            normalizedNumber,
            callerName,
            connected: state == 'ACTIVE',
          );
          break;

        case 'HOLDING':
          log(
            '[PhoneStateController] Detected HOLDING call on app start/resume: $normalizedNumber',
          );

          // 발신자 정보 초기화 이벤트 트리거
          appEventBus.fire(CallSearchResetEvent(normalizedNumber));

          // 통화 중이므로 인코밍 콜 노티피케이션 취소 및 타이머 정지
          _stopIncomingCallRefreshTimer();
          try {
            await LocalNotificationService.cancelNotification(9876);
            log('[PhoneStateController] 홀드 상태에서 수신 전화 노티피케이션 취소');
          } catch (e) {
            log('[PhoneStateController] 수신 전화 노티피케이션 취소 오류: $e');
          }

          // 홀드 상태는 ACTIVE 상태로 간주하고 connected = true로 설정
          notifyServiceCallState(
            'onCall',
            normalizedNumber,
            callerName,
            connected: true,
          );
          break;

        default:
          log(
            '[PhoneStateController] Unhandled call state: $state for number: $normalizedNumber',
          );
          break;
      }
    } catch (e) {
      log('[PhoneStateController] Error syncing initial call state: $e');
    }
  }

  // 정기적인 통화 상태 체크 타이머 시작
  void _startCallStateCheckTimer() {
    _callStateCheckTimer?.cancel();

    // 2초마다 현재 통화 상태 체크
    _callStateCheckTimer = Timer.periodic(const Duration(seconds: 2), (
      _,
    ) async {
      final now = DateTime.now();

      // 마지막 체크 이후 너무 짧은 시간이 지났으면 스킵 (최소 1.5초)
      if (_lastCallStateCheckTime != null &&
          now.difference(_lastCallStateCheckTime!).inMilliseconds < 1500) {
        return;
      }

      _lastCallStateCheckTime = now;

      try {
        final callDetails = await NativeMethods.getCurrentCallState();
        log('[PhoneStateController] 정기 통화 상태 체크 결과: $callDetails');

        final state = callDetails['state'] as String? ?? 'IDLE';
        final number = callDetails['number'] as String?;

        // RINGING 상태이고 전화번호가 있는 경우
        if (state == 'RINGING' && number != null && number.isNotEmpty) {
          final normalizedNumber = normalizePhone(number);

          // 차단된 번호인지 확인 (이 부분이 먼저 실행되도록 수정)
          bool isBlocked = false;
          try {
            isBlocked = await _blockedNumbersController.isNumberBlockedAsync(
              normalizedNumber,
              addHistory: false, // 기록은 실제 전화 이벤트 처리 시에만 추가
            );
          } catch (e) {
            log('[PhoneStateController] Error checking block status: $e');
          }

          if (isBlocked) {
            log(
              '[PhoneStateController] Call from $normalizedNumber is BLOCKED.',
            );
            try {
              await NativeMethods.rejectCall();
              log(
                '[PhoneStateController] Rejected blocked call from timer check.',
              );
            } catch (e) {
              log('[PhoneStateController] Error rejecting call: $e');
            }
            return; // 차단된 번호라면 여기서 처리 종료
          }

          // 현재 표시 중인 번호와 같으면 갱신하지 않음 (타이머에서 이미 처리 중)
          if (_currentIncomingNumber == normalizedNumber &&
              _incomingCallRefreshTimer != null) {
            log(
              '[PhoneStateController] 이미 같은 번호로 노티피케이션 표시 중: $normalizedNumber',
            );
            return;
          }

          // 수신 전화 노티피케이션 표시 및 타이머 시작
          try {
            log('[PhoneStateController] 정기 체크에서 수신 전화 감지: $normalizedNumber');

            // 차단되지 않은 번호에 대해서만 발신자 정보 초기화 이벤트 트리거
            appEventBus.fire(CallSearchResetEvent(normalizedNumber));

            // 연락처 이름 가져오기
            String callerName = await contactsController.getContactName(
              normalizedNumber,
            );
            await LocalNotificationService.showIncomingCallNotification(
              phoneNumber: normalizedNumber,
              callerName: callerName,
            );
            log('[PhoneStateController] 정기 체크 후 수신 전화 노티피케이션 표시 성공');

            // 노티피케이션 갱신 타이머 시작
            _startIncomingCallRefreshTimer(normalizedNumber, callerName);

            // 백그라운드 서비스에도 알림
            notifyServiceCallState(
              'onIncomingNumber',
              normalizedNumber,
              callerName,
            );
          } catch (e) {
            log('[PhoneStateController] 정기 체크 후 수신 전화 노티피케이션 표시 오류: $e');
          }
        }
        // RINGING이 아닌데 노티피케이션 표시 중이면 취소
        else if (state != 'RINGING' && _incomingCallRefreshTimer != null) {
          log('[PhoneStateController] 정기 체크: RINGING 아님, 노티피케이션 정리');
          _stopIncomingCallRefreshTimer();
          try {
            await LocalNotificationService.cancelNotification(9876);
            log('[PhoneStateController] 정기 체크 후 수신 전화 노티피케이션 취소');
          } catch (e) {
            log('[PhoneStateController] 수신 전화 노티피케이션 취소 오류: $e');
          }

          // ACTIVE 상태로 변경된 경우
          if ((state == 'ACTIVE' || state == 'DIALING') &&
              number != null &&
              number.isNotEmpty) {
            log('[PhoneStateController] 정기 체크: 통화 활성화 감지');
            final normalizedNumber = normalizePhone(number);

            // 백그라운드 서비스에 통화 시작 알림
            notifyServiceCallState(
              'onCall',
              normalizedNumber,
              '',
              connected: state == 'ACTIVE',
            );
          }
        }
      } catch (e) {
        log('[PhoneStateController] 정기 통화 상태 체크 오류: $e');
      }
    });

    log('[PhoneStateController] 정기 통화 상태 체크 타이머 시작 (2초 간격)');
  }
}
