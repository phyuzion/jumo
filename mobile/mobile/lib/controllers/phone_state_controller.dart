import 'dart:async';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:mobile/main.dart';
import 'package:mobile/repositories/auth_repository.dart';
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

  // Getters, Setters, Helpers
  StreamSubscription<PhoneState>? _phoneStateSubscription;
  StreamSubscription? _searchResetSubscription;
  StreamSubscription? _callStateSyncSubscription; // 추가

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
  
  // 마지막 수신한 통화 상태
  Map<String, dynamic>? _lastReceivedCallDetails;

  // 생성자에 이벤트 구독 추가
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
    
    // 통화 상태 이벤트 구독 추가
    _callStateSyncSubscription = appEventBus.on<CallStateSyncEvent>().listen(
      _handleCallStateSyncEvent,
    );
    log('[PhoneStateController] 통화 상태 동기화 이벤트 구독 시작');
  }
  
  // 통화 상태 이벤트 핸들러
  void _handleCallStateSyncEvent(CallStateSyncEvent event) {
    // 마지막 받은 상태와 동일하면 처리 생략
    if (_areCallDetailsEqual(_lastReceivedCallDetails, event.callDetails)) {
      return;
    }
    
    // 새 상태 저장
    _lastReceivedCallDetails = Map<String, dynamic>.from(event.callDetails);
    _lastCallStateCheckTime = DateTime.now();
    
    // 정기 체크 타이머 멈추고 이벤트 기반으로 처리
    if (_callStateCheckTimer?.isActive ?? false) {
      _callStateCheckTimer!.cancel();
      _callStateCheckTimer = null;
      log('[PhoneStateController] 직접 통화 상태 체크 타이머 정지 (이벤트 기반으로 전환)');
    }
    
    // 필요한 경우에만 상태 처리 (예: RINGING 감지)
    final callDetails = event.callDetails;
    
    try {
      final state = callDetails['state'] as String? ?? 'IDLE';
      final number = callDetails['number'] as String?;
      
      // RINGING 상태이고 전화번호가 있는 경우에만 처리
      if (state == 'RINGING' && number != null && number.isNotEmpty) {
        _processIncomingCall(number);
      }
      // ACTIVE 상태로 변경된 경우
      else if ((state == 'ACTIVE' || state == 'DIALING') && 
               number != null && 
               number.isNotEmpty) {
        _processActiveCall(number);
      }
      // IDLE 상태이고 노티피케이션이 표시 중이면 취소
      else if (state == 'IDLE' && _incomingCallRefreshTimer != null) {
        _clearIncomingCallNotification();
      }
    } catch (e) {
      log('[PhoneStateController] 통화 상태 이벤트 처리 중 오류: $e');
    }
  }
  
  // RINGING 상태 처리 메서드
  Future<void> _processIncomingCall(String number) async {
    final normalizedNumber = normalizePhone(number);
    
    // 차단된 번호인지 확인
    bool isBlocked = false;
    try {
      isBlocked = await _blockedNumbersController.isNumberBlockedAsync(
        normalizedNumber,
        addHistory: false,
      );
    } catch (e) {
      log('[PhoneStateController] 차단 상태 확인 오류: $e');
    }
    
    if (isBlocked) {
      log('[PhoneStateController] 차단된 번호 감지: $normalizedNumber');
      try {
        await NativeMethods.rejectCall();
      } catch (e) {
        log('[PhoneStateController] 차단된 전화 거절 오류: $e');
      }
      return;
    }
    
    // 현재 표시 중인 번호와 같으면 갱신하지 않음
    if (_currentIncomingNumber == normalizedNumber && 
        _incomingCallRefreshTimer != null) {
      return;
    }
    
    log('[PhoneStateController] 수신 전화 감지: $normalizedNumber');
    
    // 발신자 정보 초기화 이벤트
    appEventBus.fire(CallSearchResetEvent(normalizedNumber));
    
    // 연락처 이름 가져오기
    final callerName = await contactsController.getContactName(normalizedNumber);
    
    // 노티피케이션 표시 및 타이머 시작
    try {
      await LocalNotificationService.showIncomingCallNotification(
        phoneNumber: normalizedNumber,
        callerName: callerName,
      );
      _startIncomingCallRefreshTimer(normalizedNumber, callerName);
    } catch (e) {
      log('[PhoneStateController] 수신 전화 노티피케이션 표시 오류: $e');
    }
    
    // 백그라운드 서비스에 상태 알림
    notifyServiceCallState(
      'onIncomingNumber',
      normalizedNumber,
      callerName,
    );
  }
  
  // ACTIVE 상태 처리 메서드
  void _processActiveCall(String number) {
    final normalizedNumber = normalizePhone(number);
    
    // 노티피케이션 정리
    _clearIncomingCallNotification();
    
    // 백그라운드 서비스에 상태 알림
    notifyServiceCallState(
      'onCall',
      normalizedNumber,
      '',
      connected: true,
    );
  }
  
  // 인코밍 콜 노티피케이션 정리
  Future<void> _clearIncomingCallNotification() async {
    _stopIncomingCallRefreshTimer();
    try {
      await LocalNotificationService.cancelNotification(9876);
      log('[PhoneStateController] 수신 전화 노티피케이션 취소');
    } catch (e) {
      log('[PhoneStateController] 수신 전화 노티피케이션 취소 오류: $e');
    }
  }
  
  // 두 통화 상태가 동일한지 비교하는 헬퍼 메서드
  bool _areCallDetailsEqual(Map<String, dynamic>? oldDetails, Map<String, dynamic>? newDetails) {
    // 둘 중 하나라도 null이면 동일하지 않음
    if (oldDetails == null || newDetails == null) {
      return false;
    }
    
    // 핵심 상태 필드 비교
    final fields = ['active_state', 'active_number', 'holding_state', 'holding_number', 'ringing_state', 'ringing_number'];
    for (final field in fields) {
      if (oldDetails[field] != newDetails[field]) {
        return false;
      }
    }
    
    return true;
  }

  // 로그인 상태 확인 후 타이머 시작
  Future<void> _checkLoginAndStartTimer() async {
    try {
      final authRepository = getIt<AuthRepository>();
      final isLoggedIn = await authRepository.getLoginStatus();

      if (isLoggedIn) {
        log('[PhoneStateController] 로그인 상태 확인: 로그인됨, 이벤트 기반 상태 구독 중');
        // 이제 이벤트 기반으로 처리하므로 타이머 시작하지 않음
        // _startCallStateCheckTimer();
      } else {
        log('[PhoneStateController] 로그인 상태 확인: 로그인되지 않음');
      }
    } catch (e) {
      log('[PhoneStateController] 로그인 상태 확인 중 오류: $e');
    }
  }

  void startListening() {
    _phoneStateSubscription?.cancel();
    _phoneStateSubscription = PhoneState.stream.listen((event) async {
      final isDef = await NativeDefaultDialerMethods.isDefaultDialer();
      if (!isDef) {
        await _handlePhoneStateEvent(event.status, event.number);
      }
    });
    log(
      '[PhoneStateController.startListening] Listening to phone state stream.',
    );

    // 로그인 상태 확인 후 타이머 시작
    _checkLoginAndStartTimer();
  }

  void stopListening() {
    _phoneStateSubscription?.cancel();
    _phoneStateSubscription = null;
    _searchResetSubscription?.cancel();
    _searchResetSubscription = null;
    _callStateSyncSubscription?.cancel(); // 추가
    _callStateSyncSubscription = null; // 추가
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
          '[PhoneStateController] 수신 전화 노티피케이션 갱신 성공 ($_incomingCallNotificationCount/20)',
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

  // 대기 통화 처리 메서드 추가
  Future<void> handleWaitingCall(String activeNumber, String waitingNumber) async {
    log('[PhoneStateController] 대기 통화 처리: 활성=$activeNumber, 대기=$waitingNumber');
    
    // 활성 통화와 대기 통화 번호 정규화
    final normalizedActiveNumber = normalizePhone(activeNumber);
    final normalizedWaitingNumber = normalizePhone(waitingNumber);
    
    // 차단된 번호인지 확인
    bool isBlocked = false;
    try {
      isBlocked = await _blockedNumbersController.isNumberBlockedAsync(
        normalizedWaitingNumber,
        addHistory: false,
      );
    } catch (e) {
      log('[PhoneStateController] 대기 통화 차단 상태 확인 오류: $e');
    }
    
    // 차단된 번호면 바로 거절
    if (isBlocked) {
      log('[PhoneStateController] 차단된 대기 통화 감지: $normalizedWaitingNumber, 자동 거절');
      try {
        await NativeMethods.rejectCall();
      } catch (e) {
        log('[PhoneStateController] 차단된 대기 통화 거절 오류: $e');
      }
      return;
    }
    
    // 중요: 노티피케이션 정리 - 기존 수신 전화 노티피케이션이 있다면 취소
    _stopIncomingCallRefreshTimer();
    try {
      await LocalNotificationService.cancelNotification(9876);
      log('[PhoneStateController] 대기 통화 처리: 기존 수신 전화 노티피케이션 취소 완료');
    } catch (e) {
      log('[PhoneStateController] 노티피케이션 취소 오류: $e');
    }
    
    // 발신자 정보 초기화 이벤트
    appEventBus.fire(CallSearchResetEvent(normalizedWaitingNumber));
    
    // 중요: 대기 통화는 일반 수신 전화와 다르게 처리
    // CallWaitingEvent 발행하여 UI에 알림
    log('[PhoneStateController] 대기 통화 이벤트 발행: 활성=$normalizedActiveNumber, 대기=$normalizedWaitingNumber');
    appEventBus.fire(CallWaitingEvent(
      activeNumber: normalizedActiveNumber,
      waitingNumber: normalizedWaitingNumber
    ));
    
    // 백그라운드 서비스에는 활성 상태 유지하면서 웨이팅 정보 추가
    final service = FlutterBackgroundService();
    service.invoke('callWaitingDetected', {
      'active_number': normalizedActiveNumber,
      'waiting_number': normalizedWaitingNumber
    });
    
    // 중요: 대기 통화는 일반 인코밍 콜 처리 경로를 타지 않도록 함
    // 따라서 notifyServiceCallState는 호출하지 않음
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
        // 기본 전화 앱으로 설정될 때 발생하는 onCallEnded 이벤트는 무시
    if (method == 'onCallEnded' && reason == 'default_dialer_change') {
      log('[PhoneStateController] 기본 전화 앱 설정 변경으로 인한 onCallEnded 이벤트 무시');
      return;
    }

    switch (method) {
      // 대기 통화 이벤트 처리 추가
      case 'onWaitingCall':
        if (args is Map) {
          final activeNumber = args['active_number'] as String? ?? '';
          final waitingNumber = args['waiting_number'] as String? ?? '';
          
          if (activeNumber.isNotEmpty && waitingNumber.isNotEmpty) {
            log('[PhoneStateController] 네이티브에서 대기 통화 이벤트 수신: 활성=$activeNumber, 대기=$waitingNumber');
            // 먼저 인코밍 콜 알림 타이머 정지
            _stopIncomingCallRefreshTimer();
            try {
              await LocalNotificationService.cancelNotification(9876);
              log('[PhoneStateController] 대기 통화 전 노티피케이션 취소 성공');
            } catch (e) {
              log('[PhoneStateController] 대기 통화 전 노티피케이션 취소 실패: $e');
            }
            
            // 대기 통화 전용 처리
            await handleWaitingCall(activeNumber, waitingNumber);
            return; // 대기 통화는 일반 인코밍 콜로 처리하지 않고 여기서 종료
          }
        }
        break;
        
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
        normalizedNumber,
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
    log(
      '[PhoneStateController][notifyServiceCallState] Method called: stateMethod=$stateMethod, number=$number, name=$callerName, connected=$connected, reason=$reason',
    );

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
        // 통화 종료 이벤트 발생 전에 현재 통화 상태 확인
        _checkCallStateBeforeEnding(service, number, callerName, reasonValue);
        return; // 비동기 처리를 위해 여기서 반환
      default:
        state = 'unknown';
    }

    if (state == 'unknown') {
      log(
        '[PhoneStateController][notifyServiceCallState] Unknown stateMethod $stateMethod, not invoking service.',
      );
      return;
    }

    final payload = {
      'state': state,
      'number': number,
      'callerName': callerName,
      'connected': isConnectedValue,
      'reason': reasonValue,
    };

    log(
      '[PhoneStateController][notifyServiceCallState] Invoking service with callStateChanged. Payload: $payload',
    );
    try {
      service.invoke('callStateChanged', payload);
      log(
        '[PhoneStateController][notifyServiceCallState] Successfully invoked service with callStateChanged.',
      );
    } catch (e) {
      log(
        '[PhoneStateController][notifyServiceCallState] Error invoking service: $e',
      );
    }
  }

  // 통화 종료 이벤트 발생 전 현재 통화 상태 확인 메서드
  Future<void> _checkCallStateBeforeEnding(
    FlutterBackgroundService service,
    String number,
    String callerName,
    String reason,
  ) async {
    try {
      // 현재 통화 상태를 네이티브 측에서 가져옴
      final callDetails = await NativeMethods.getCurrentCallState();
      
      // 활성/대기/수신 통화 확인
      final activeState = callDetails['active_state'] as String? ?? 'IDLE';
      final activeNumber = callDetails['active_number'] as String?;
      final holdingState = callDetails['holding_state'] as String? ?? 'IDLE';
      final holdingNumber = callDetails['holding_number'] as String?;
      final ringingState = callDetails['ringing_state'] as String? ?? 'IDLE';
      final ringingNumber = callDetails['ringing_number'] as String?;
      
      // 통화 존재 여부 확인
      final hasActiveCall = activeState == 'ACTIVE' && activeNumber != null && activeNumber.isNotEmpty;
      final hasHoldingCall = holdingState == 'HOLDING' && holdingNumber != null && holdingNumber.isNotEmpty;
      final hasRingingCall = ringingState == 'RINGING' && ringingNumber != null && ringingNumber.isNotEmpty;
      
      log(
        '[PhoneStateController] 통화 종료 전 상태 확인: 활성=$hasActiveCall, 대기=$hasHoldingCall, 수신=$hasRingingCall',
      );
      
      // 활성/대기/수신 통화 중 하나라도 있으면 ended 이벤트를 발생시키지 않음
      if (hasActiveCall || hasHoldingCall || hasRingingCall) {
        log(
          '[PhoneStateController] 다른 통화가 있어 ended 이벤트를 무시합니다.',
        );
        return;
      }
      
      // 통화가 없는 경우에만 ended 이벤트 발생
      final payload = {
        'state': 'ended',
        'number': number,
        'callerName': callerName,
        'connected': false,
        'reason': reason,
      };
      
      try {
        service.invoke('callStateChanged', payload);
        log(
          '[PhoneStateController] 모든 통화가 없어 ended 이벤트를 발생시킵니다.',
        );
      } catch (e) {
        log(
          '[PhoneStateController] Error invoking service with callStateChanged: $e',
        );
      }
    } catch (e) {
      log('[PhoneStateController] Error checking call state before ending: $e');
      
      // 오류 발생 시 안전하게 ended 이벤트 발생
      final payload = {
        'state': 'ended',
        'number': number,
        'callerName': callerName,
        'connected': false,
        'reason': reason + ' (check_error)',
      };
      
      try {
        service.invoke('callStateChanged', payload);
      } catch (e) {
        log(
          '[PhoneStateController] Error invoking service with callStateChanged: $e',
        );
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      syncInitialCallState();
      // 앱이 재개될 때 로그인 상태 확인 후 타이머 시작/중지
      _checkLoginAndStartTimer();
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

      // 활성 통화, 대기 통화, 수신 통화 확인
      final activeNumber = callDetails['active_number'] as String?;
      final activeState = callDetails['active_state'] as String?;
      final holdingNumber = callDetails['holding_number'] as String?; 
      final holdingState = callDetails['holding_state'] as String?;
      final ringingNumber = callDetails['ringing_number'] as String?;
      final ringingState = callDetails['ringing_state'] as String?;

      // 활성 통화나 대기 통화, 수신 통화가 없으면 종료
      if ((activeNumber == null || activeNumber.isEmpty || activeState != 'ACTIVE') &&
          (holdingNumber == null || holdingNumber.isEmpty || holdingState != 'HOLDING') &&
          (ringingNumber == null || ringingNumber.isEmpty || ringingState != 'RINGING')) {
        log(
          '[PhoneStateController] No active/holding/ringing calls detected',
        );
        return;
      }

      // 수신 통화가 있으면 처리
      if (ringingNumber != null && ringingNumber.isNotEmpty && ringingState == 'RINGING') {
        final normalizedNumber = normalizePhone(ringingNumber);
        log(
          '[PhoneStateController] Detected RINGING call on app start/resume: $normalizedNumber',
        );

        // 차단된 번호인지 확인
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
          String callerName = await contactsController.getContactName(
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
          '',
        );
        return;  // 수신 통화 처리 후 종료
      }

      // 활성 통화가 있으면 처리
      if (activeNumber != null && activeNumber.isNotEmpty && activeState == 'ACTIVE') {
        final normalizedNumber = normalizePhone(activeNumber);
        log(
          '[PhoneStateController] Detected ACTIVE call on app start/resume: $normalizedNumber',
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
          '',
          connected: true,
        );
        return;  // 활성 통화 처리 후 종료
      }

      // 대기 통화가 있으면 처리
      if (holdingNumber != null && holdingNumber.isNotEmpty && holdingState == 'HOLDING') {
        final normalizedNumber = normalizePhone(holdingNumber);
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
          '',
          connected: true,
        );
      }
    } catch (e) {
      log('[PhoneStateController] Error syncing initial call state: $e');
    }
  }

  // 정기적인 통화 상태 체크 타이머 시작
  void _startCallStateCheckTimer() async {
    // 먼저 로그인 상태 확인
    final authRepository = getIt<AuthRepository>();
    final isLoggedIn = await authRepository.getLoginStatus();

    if (!isLoggedIn) {
      log('[PhoneStateController] 로그인되지 않은 상태에서 타이머 시작 요청, 무시함');
      // 기존 타이머가 있으면 정지
      if (_callStateCheckTimer?.isActive ?? false) {
        _callStateCheckTimer!.cancel();
        _callStateCheckTimer = null;
        log('[PhoneStateController] 로그인되지 않아 정기 통화 상태 체크 타이머 정지');
      }
      return;
    }

    // 이미 실행 중인 타이머가 있으면 취소
    _callStateCheckTimer?.cancel();

    // 마지막 통화 상태 저장용 변수 추가
    Map<String, dynamic>? lastCallDetails;

    // 2초마다 현재 통화 상태 체크
    _callStateCheckTimer = Timer.periodic(const Duration(seconds: 2), (
      _,
    ) async {
      // 현재 로그인 상태 재확인
      final stillLoggedIn = await authRepository.getLoginStatus();
      if (!stillLoggedIn) {
        // 로그인 상태가 아니면 타이머 중지
        _callStateCheckTimer?.cancel();
        _callStateCheckTimer = null;
        log('[PhoneStateController] 로그인 상태가 변경되어 정기 통화 상태 체크 타이머 정지');
        return;
      }

      final now = DateTime.now();

      // 마지막 체크 이후 너무 짧은 시간이 지났으면 스킵 (최소 1.5초)
      if (_lastCallStateCheckTime != null &&
          now.difference(_lastCallStateCheckTime!).inMilliseconds < 1500) {
        return;
      }

      _lastCallStateCheckTime = now;

      try {
        final callDetails = await NativeMethods.getCurrentCallState();
        
        // 이전 상태와 현재 상태 비교 (핵심 필드만)
        bool stateChanged = lastCallDetails == null;
        if (!stateChanged) {
          final fields = ['active_state', 'active_number', 'holding_state', 
                         'holding_number', 'ringing_state', 'ringing_number'];
          for (final field in fields) {
            if (lastCallDetails![field] != callDetails[field]) {
              stateChanged = true;
              break;
            }
          }
        }
        
        // 상태 변경이 없으면 로그만 남기고 종료
        if (!stateChanged) {
          // log('[PhoneStateController] 정기 통화 상태 체크: 변경 없음, 처리 건너뜀');
          return;
        }
        
        // 상태가 변경되었으면 로그 남기기
        log('[PhoneStateController] 정기 통화 상태 체크 결과: $callDetails');
        
        // 상태 업데이트
        lastCallDetails = Map<String, dynamic>.from(callDetails);

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
