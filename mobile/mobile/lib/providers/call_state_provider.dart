import 'dart:async';
import 'dart:developer';
import 'package:flutter/foundation.dart';
import 'package:mobile/controllers/phone_state_controller.dart';
import 'package:mobile/services/native_methods.dart';
import 'package:mobile/services/native_default_dialer_methods.dart';
import 'package:mobile/services/local_notification_service.dart';
import 'package:mobile/controllers/call_log_controller.dart';
import 'package:mobile/controllers/contacts_controller.dart';
import 'package:proximity_sensor/proximity_sensor.dart';
import 'package:mobile/utils/app_event_bus.dart';

// 통화 상태 enum 정의 (HomeScreen에서 가져옴 - 여기서 관리하는 것이 더 적절)
enum CallState { idle, incoming, active, ended }

// 로컬 노티피케이션용 상수 (local_notification_service.dart에 정의된 값과 일치시킴)
const int INCOMING_CALL_NOTIFICATION_ID = 9876;

class CallStateProvider with ChangeNotifier {
  final PhoneStateController phoneStateController;
  final CallLogController callLogController;
  final ContactsController contactsController;

  CallState _callState = CallState.idle;
  String _number = '';
  String _callerName = '';
  int _duration = 0; // <<< 유지 (백그라운드에서 값 받음)
  bool _isConnected = false; // active 상태 내 연결 여부
  bool _isPopupVisible = false;
  String _callEndReason = ''; // 통화 종료 이유 (missed 등)

  // 버튼 상태 변수
  bool _isMuted = false;
  bool _isHold = false;
  bool _isSpeakerOn = false;

  // 대기 중인 통화 및 수신 중인 통화 정보
  String? _holdingCallNumber;
  String? _holdingCallerName;
  String? _ringingCallNumber;
  String? _ringingCallerName;

  // 마지막으로 조회한 통화 상태 정보 (깊은 비교용)
  Map<String, dynamic>? _lastCallDetails;

  Timer? _endedStateTimer;
  int _endedCountdownSeconds = 10;

  // 통화 상태 동기화 타이머
  Timer? _callStateCheckTimer;

  // 근접 센서 스트림 구독 관리를 위한 변수
  StreamSubscription<dynamic>? _proximitySensorSubscription;

  // 추가된 멤버 변수들
  String? _currentlyFetchingNameForNumber;
  final Set<String> _nameFetchedAttemptedForNumbers = {};

  // 이벤트 구독 변수 추가
  StreamSubscription? _resetEventSubscription;

  // Getters
  CallState get callState => _callState;
  String get number => _number;
  String get callerName => _callerName;
  int get duration => _duration;
  bool get isConnected => _isConnected;
  bool get isPopupVisible => _isPopupVisible;
  String get callEndReason => _callEndReason;

  bool get isMuted => _isMuted;
  bool get isHold => _isHold;
  bool get isSpeakerOn => _isSpeakerOn;
  int get endedCountdownSeconds => _endedCountdownSeconds;

  // 대기 중인 통화 및 수신 중인 통화 Getters
  String? get holdingCallNumber => _holdingCallNumber;
  String? get holdingCallerName => _holdingCallerName;
  String? get ringingCallNumber => _ringingCallNumber;
  String? get ringingCallerName => _ringingCallerName;

  // 생성자 수정: 리스너 등록 및 타이머 시작
  CallStateProvider(
    this.phoneStateController,
    this.callLogController,
    this.contactsController,
  ) {
    contactsController.addListener(_onContactsUpdated);

    // 초기화 이벤트 구독
    _resetEventSubscription = appEventBus.on<CallSearchResetEvent>().listen(
      _handleResetEvent,
    );
    log('[CallStateProvider] 생성됨. 리셋 이벤트 리스너 설정 완료.');
    
    // 통화 상태 동기화 타이머 시작
    startCallStateCheckTimer();
  }

  // 통화 상태 동기화 타이머 시작
  void startCallStateCheckTimer() {
    _callStateCheckTimer?.cancel();
    _callStateCheckTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      syncCallState();
    });
    log('[CallStateProvider] 통화 상태 동기화 타이머 시작 (2초 간격)');
  }

  // 통화 상태 동기화 함수
  Future<void> syncCallState() async {
    try {
      final callDetails = await NativeMethods.getCurrentCallState();
      
      // 앱 전체에서 getCurrentCallState 중복 호출을 방지하기 위해
      // 이벤트 버스로 결과 전파
      appEventBus.fire(CallStateSyncEvent(callDetails));
      
      log('[CallStateProvider] 통화 상태 정보: $callDetails');

      // 이전 상태와 현재 상태 비교
      if (_areCallDetailsEqual(_lastCallDetails, callDetails)) {
        log('[CallStateProvider] 통화 상태 변경 없음. UI 업데이트 생략');
        return; // 상태 변경이 없으면 함수 종료
      }

      // 상태가 변경되었으면 마지막 상태 업데이트
      _lastCallDetails = Map<String, dynamic>.from(callDetails);
      log('[CallStateProvider] 통화 상태 변경 감지. 처리 시작');

      // 활성 통화, 대기 통화, 수신 통화 정보 추출
      final activeState = callDetails['active_state'] as String? ?? 'IDLE';
      final activeNumber = callDetails['active_number'] as String?;
      final holdingState = callDetails['holding_state'] as String? ?? 'IDLE';
      final holdingNumber = callDetails['holding_number'] as String?;
      final ringingState = callDetails['ringing_state'] as String? ?? 'IDLE';
      final ringingNumber = callDetails['ringing_number'] as String?;
      
      // 통화 존재 여부 확인
      final bool hasActiveCall = activeState == 'ACTIVE' && activeNumber != null && activeNumber.isNotEmpty;
      final bool hasHoldingCall = holdingState == 'HOLDING' && holdingNumber != null && holdingNumber.isNotEmpty;
      final bool hasRingingCall = ringingState == 'RINGING' && ringingNumber != null && ringingNumber.isNotEmpty;
      final bool hasAnyCall = hasActiveCall || hasHoldingCall || hasRingingCall;
      
      log('[CallStateProvider] 통화 상태 분석: 활성=$hasActiveCall, 대기=$hasHoldingCall, 수신=$hasRingingCall');

      // 수신 중인 통화 정보 업데이트 (항상 최신 상태 유지)
      if (hasRingingCall) {
        // 항상 정확한 정보 유지를 위해 업데이트 조건을 완화
        if (_ringingCallNumber != ringingNumber || _ringingCallerName == null) {
          _ringingCallNumber = ringingNumber;
          _ringingCallerName = await contactsController.getContactName(ringingNumber!);
          log('[CallStateProvider] 수신 중인 통화 정보 업데이트: $_ringingCallNumber, $_ringingCallerName');
          
          // 수신 중인 통화가 있을 때 적절한 상태 전환 처리
          if (hasActiveCall) {
            // 활성 통화가 있는 경우, 수신 통화는 대기 통화로 처리함
            // (별도의 상태 전환 없이 대기 통화 정보만 설정)
            log('[CallStateProvider] 활성 통화 중에 수신된 통화는 대기 통화로 처리: $_ringingCallNumber');
            
            // 이벤트 발행하여 UI에서 대기 통화 처리하도록 함
            appEventBus.fire(CallWaitingEvent(
              activeNumber: activeNumber!, 
              waitingNumber: ringingNumber
            ));
          } else if (_callState != CallState.incoming) {
            // 활성 통화가 없고, 현재 incoming 상태가 아닌 경우에만 상태 변경
            await updateCallState(
              state: CallState.incoming, 
              number: ringingNumber, 
              callerName: _ringingCallerName ?? ''
            );
          }
        }
        // 로그는 유지하되 상태 변경은 하지 않음
        else {
          log('[CallStateProvider] 수신 중인 통화 정보 유지: $_ringingCallNumber, $_ringingCallerName');
        }
      } else {
        // 수신 통화가 없으면 관련 상태 정리
        _ringingCallNumber = null;
        _ringingCallerName = null;
      }

      // 대기 중인 통화 정보 업데이트
      if (hasHoldingCall) {
        if (_holdingCallNumber != holdingNumber) {
          _holdingCallNumber = holdingNumber;
          _holdingCallerName = await contactsController.getContactName(holdingNumber!);
          log('[CallStateProvider] 대기 중인 통화 정보 업데이트: $_holdingCallNumber, $_holdingCallerName');
        }
      } else {
        // 대기 통화가 없으면 관련 상태 정리
        _holdingCallNumber = null;
        _holdingCallerName = null;
      }

      // 활성 통화 정보 업데이트
      if (hasActiveCall) {
        final bool isDialing = activeState == 'DIALING';
        // 현재 번호와 다르거나 상태가 active가 아닌 경우 상태 업데이트
        if (_number != activeNumber || _callState != CallState.active) {
          log('[CallStateProvider] 활성 통화 변경: $_number -> $activeNumber (발신 상태: $isDialing)');
          
          // 전화번호가 바뀌면 이름을 명시적으로 초기화 (이전 이름 제거)
          if (_number != activeNumber) {
            _callerName = '';  // 이름 초기화
            log('[CallStateProvider] 새로운 번호로 변경되어 발신자 이름 초기화');
          }
          
          // 활성 통화 정보 업데이트
          await updateCallState(
            state: CallState.active,
            number: activeNumber!,
            isConnected: !isDialing,  // DIALING 상태면 아직 연결되지 않은 것으로 처리
          );
        }
      } 
      // 활성 통화가 없을 때 상태 처리
      else if (_callState == CallState.active) {
        // 대기 중인 통화나 수신 통화가 있으면 현재 상태 유지
        if (hasHoldingCall || hasRingingCall) {
          log('[CallStateProvider] 활성 통화는 없지만 대기/수신 통화가 있어 상태 유지');
        } 
        // 모든 통화가 없으면 ended 상태로 전환 (idle 직행은 하지 않음)
        else {
          log('[CallStateProvider] 모든 통화 없음, ended 상태로 변경');
          await updateCallState(
            state: CallState.ended,
            number: _number,
            reason: 'sync_all_calls_ended'
          );
        }
      } 
      // 통화가 끝난 상태에서 새로운 통화 발생
      else if (_callState == CallState.ended && hasAnyCall) {
        log('[CallStateProvider] 통화 종료 상태에서 새로운 통화 감지. 상태 복구');
        
        // 활성 통화가 있으면 active 상태로, 수신 통화가 있으면 incoming 상태로 업데이트
        if (hasActiveCall) {
          await updateCallState(
            state: CallState.active,
            number: activeNumber!,
            isConnected: true,
          );
        } else if (hasRingingCall) {
          await updateCallState(
            state: CallState.incoming,
            number: ringingNumber!,
          );
        } else if (hasHoldingCall) {
          // 대기 통화만 있는 경우 활성화
          log('[CallStateProvider] 대기 통화만 존재. 활성화 시도');
          await NativeMethods.switchCalls();
          // 이후 다음 동기화에서 상태 업데이트됨
        }
      }
      
      // 상태 변경이 없어도 대기 중인 통화나 수신 중인 통화가 있으면 UI 업데이트
      if (_holdingCallNumber != null || _ringingCallNumber != null) {
        notifyListeners();
      }
    } catch (e) {
      log('[CallStateProvider] 통화 상태 동기화 오류: $e');
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

  // 대기 중인 통화 수락 함수
  Future<void> acceptWaitingCall() async {
    try {
      log('[CallStateProvider] 대기 후 수신 시도');
      // 현재 통화를 대기 상태로 전환
      await NativeMethods.toggleHold(true);
      _isHold = true;
      
      // 잠시 대기 후 수신 통화 받기
      await Future.delayed(const Duration(milliseconds: 300));
      await NativeMethods.acceptCall();
      
      // 상태 즉시 동기화
      await syncCallState();
    } catch (e) {
      log('[CallStateProvider] 대기 후 수신 오류: $e');
    }
  }

  // 대기 중인 통화 거절 함수
  Future<void> rejectWaitingCall() async {
    try {
      log('[CallStateProvider] 수신 통화 거절');
      await NativeMethods.rejectCall();
      _ringingCallNumber = null;
      _ringingCallerName = null;
      notifyListeners();
    } catch (e) {
      log('[CallStateProvider] 수신 통화 거절 오류: $e');
    }
  }

  // 현재 통화 종료 후 대기 중인 통화 수락 함수
  Future<void> endAndAcceptWaitingCall() async {
    try {
      log('[CallStateProvider] 현재 통화 종료 후 수신 통화 수락');
      
      // 네이티브에서 원자적으로 처리하도록 수정
      await NativeMethods.endAndAcceptWaitingCall();
      
      // 상태 즉시 동기화
      await Future.delayed(const Duration(milliseconds: 500));
      await syncCallState();
    } catch (e) {
      log('[CallStateProvider] 통화 종료 후 수신 오류: $e');
    }
  }

  // 활성 통화와 대기 통화 전환 함수
  Future<void> switchCalls() async {
    try {
      log('[CallStateProvider] 통화 전환 시도');
      await NativeMethods.switchCalls();
      
      // 상태 즉시 동기화
      await Future.delayed(const Duration(milliseconds: 300));
      await syncCallState();
    } catch (e) {
      log('[CallStateProvider] 통화 전환 오류: $e');
    }
  }

  // <<< 연락처 업데이트 리스너 메소드 >>>
  void _onContactsUpdated() {
    // <<< 조건 변경: null 또는 isEmpty 확인 >>>
    if (!contactsController.isLoading &&
        _number.isNotEmpty &&
        (_callerName == null || _callerName.isEmpty)) {
      // <<< 수정
      _fetchAndUpdateCallerName(_number); // 이름 조회 재시도
    }
  }

  // 상태 업데이트 메소드 수정
  Future<void> updateCallState({
    required CallState state,
    String number = '',
    String callerName = '',
    bool isConnected = false,
    String reason = '',
    int duration = 0,
  }) async {
    final bool wasActive = _callState == CallState.active; // <<< 이전 상태 저장
    final CallState previousCallState = _callState; // 로깅을 위해 이전 상태 저장
    final String previousNumber = _number; // 이전 번호 저장

    // Call Ended 상태에서 새 인코밍 콜이 들어오는 경우 명시적 초기화
    if (previousCallState == CallState.ended && state == CallState.incoming) {
      log('[CallStateProvider][CRITICAL] 통화 종료 상태에서 새 인코밍 콜 감지. 상태 완전 초기화');
      resetState();
    }

    // 번호가 변경되었는지 확인
    bool numberChanged = previousNumber.isNotEmpty && previousNumber != number;
    if (numberChanged) {
      _nameFetchedAttemptedForNumbers.remove(previousNumber);
      log(
        '[CallStateProvider] Phone number changed, cleared name fetch attempt for $previousNumber',
      );
      
      // 번호가 변경되었으면 발신자 이름도 명시적으로 초기화
      _callerName = ''; // 항상 이름 초기화 (조건 제거)
      log('[CallStateProvider] Phone number changed, reset caller name to empty');
    }

    // 이름 조회 시도
    if ((state == CallState.incoming || state == CallState.active) &&
        _callerName.isEmpty &&
        number.isNotEmpty &&
        !_nameFetchedAttemptedForNumbers.contains(number) &&
        _currentlyFetchingNameForNumber != number) {
      _fetchAndUpdateCallerName(number);
    }

    // <<< 상태 변경 확인 로직 (stateTransitioned, needsCoreUpdate 등 계산) >>>
    bool stateTransitioned = previousCallState != state;
    bool infoChanged =
        _number != number ||
        _callerName != callerName ||
        _isConnected != isConnected ||
        _callEndReason != reason; // 실제 로직 사용
    bool durationChanged =
        (state == CallState.active && _duration != duration); // 실제 로직 사용
    bool needsCoreUpdate = stateTransitioned || infoChanged;

    // 이름 조회 조건 수정
    bool canAttemptNameFetch =
        _callerName.isEmpty && // 현재 _callerName이 비어있고
        (callerName.isEmpty) && // 외부에서도 이름이 주어지지 않았으며
        number.isNotEmpty && // 번호가 있고
        !_nameFetchedAttemptedForNumbers.contains(
          number,
        ) && // 해당 번호로 조회 시도한 적이 없고
        _currentlyFetchingNameForNumber != number; // 현재 해당 번호로 조회 중이 아닐 때

    bool shouldFetchName =
        (state == CallState.incoming || state == CallState.active) &&
        canAttemptNameFetch;

    bool needsNotify =
        needsCoreUpdate ||
        durationChanged ||
        (shouldFetchName &&
            _callerName.isEmpty); // 이름 조회를 시작하더라도, 실제 _callerName이 변경되어야 UI가 반응

    // <<< 상태 업데이트 적용 >>>
    if (needsCoreUpdate) {
      _callState = state;
      _number = number;
      _isConnected = isConnected;
      _callEndReason = reason;

      // <<< callerName 업데이트 로직 수정: 빈 문자열 허용 >>>
      if (callerName.isNotEmpty) {
        _callerName = callerName;
      }

      log(
        '[CallStateProvider] State updated: state=$_callState, number=$_number, name=$_callerName, reason=$_callEndReason',
      );
    }
    if (state == CallState.active) {
      _duration = duration;
    }
    
    // 상태 변경 시 이벤트 발행
    if (stateTransitioned || infoChanged) {
      String stateString = '';
      switch (state) {
        case CallState.idle: stateString = 'idle'; break;
        case CallState.incoming: stateString = 'incoming'; break;
        case CallState.active: stateString = 'active'; break;
        case CallState.ended: stateString = 'ended'; break;
      }
      
      appEventBus.fire(CallStateChangedEvent(
        state: stateString,
        number: number,
      ));
      
      log('[CallStateProvider] 통화 상태 변경 이벤트 발행: $stateString, $number');
    }

    // <<< IDLE 상태 진입 시 정보 초기화 추가 >>>
    if (state == CallState.idle) {
      _number = '';
      _callerName = '';
      _isConnected = false;
      _duration = 0;
      _callEndReason = '';
      // IDLE 상태가 되면, 이전 번호에 대한 "이름 조회 시도했음" 상태를 해제합니다.
      // 이렇게 하면 다음 통화 시 (번호가 같다면) 다시 이름을 조회할 수 있습니다.
      if (previousNumber.isNotEmpty) {
        _nameFetchedAttemptedForNumbers.remove(previousNumber);
        log(
          '[CallStateProvider] CallState is IDLE, cleared name fetch attempt for $previousNumber',
        );
      }
      log('[CallStateProvider] State changed to IDLE, resetting info.');
    }

    // --- 센서 제어 (stateTransitioned와 별개로 실행) ---
    if (!wasActive && state == CallState.active) {
      try {
        await ProximitySensor.setProximityScreenOff(true);
      } catch (e) {
        log('[Provider] Error enabling proximity screen off: $e');
      }
      _startProximityListener();
    } else if (wasActive && state != CallState.active) {
      try {
        await ProximitySensor.setProximityScreenOff(false);
      } catch (e) {
        log('[Provider] Error disabling proximity screen off: $e');
      }
      _stopProximityListener();
    }
    // --- 센서 제어 끝 ---

    // --- 상태 전환 시 1회성 작업들 ---
    if (stateTransitioned) {
      // 버튼 초기화
      if (state == CallState.incoming || state == CallState.active) {
        resetButtonStates();
      }

      // 팝업/타이머 관리
      bool isDefault = await NativeDefaultDialerMethods.isDefaultDialer();
      if (state == CallState.incoming || state == CallState.active) {
        if (isDefault) {
          _isPopupVisible = true;
        } else {
          _isPopupVisible = false;
        }
        _cancelEndedStateTimer();

        // 수신 전화 노티피케이션 표시
        if (state == CallState.incoming) {
          try {
            log(
              '[CallStateProvider] 수신 전화 노티피케이션 표시 시도: $_number, $_callerName',
            );
            await LocalNotificationService.showIncomingCallNotification(
              phoneNumber: _number,
              callerName: _callerName,
            );
          } catch (e) {
            log('[CallStateProvider] 수신 전화 노티피케이션 표시 오류: $e');
          }
        }
      } else if (state == CallState.ended) {
        _isPopupVisible = true;
        _startEndedStateTimer();

        // 통화가 종료되면 수신 전화 노티피케이션 취소
        try {
          await LocalNotificationService.cancelNotification(
            INCOMING_CALL_NOTIFICATION_ID,
          );
        } catch (e) {
          log('[CallStateProvider] 수신 전화 노티피케이션 취소 오류: $e');
        }

        if (_callEndReason == 'missed') {
          final notificationId = _number.hashCode;
          LocalNotificationService.showMissedCallNotification(
            id: notificationId,
            callerName: _callerName,
            phoneNumber: _number,
          );
        }
        await Future.delayed(const Duration(seconds: 2));
        try {
          await callLogController.refreshCallLogs();
        } catch (e) {
          log('[Provider] Error refreshing call logs: $e');
        }
      } else {
        // idle
        _isPopupVisible = false;
        _cancelEndedStateTimer();

        // idle 상태로 전환되면 수신 전화 노티피케이션 취소
        try {
          await LocalNotificationService.cancelNotification(
            INCOMING_CALL_NOTIFICATION_ID,
          );
        } catch (e) {
          log('[CallStateProvider] 수신 전화 노티피케이션 취소 오류: $e');
        }
      }
    }
    // --- 상태 전환 시 1회성 작업 끝 ---

    // <<< 리스너 호출 및 이름 조회 >>>
    if (needsNotify) {
      notifyListeners();
    }
    // 초기 이름 조회 시도
    if (shouldFetchName) {
      await _fetchAndUpdateCallerName(_number);
    }
  }

  // 이름 비동기 조회 및 업데이트 함수 (재시도 로직 제거)
  Future<void> _fetchAndUpdateCallerName(String number) async {
    if (number.isEmpty) return;
    if (_currentlyFetchingNameForNumber == number) return;
    _currentlyFetchingNameForNumber = number;
    log('[CallStateProvider] Attempting to fetch name for $number');

    try {
      // 이름 조회 시도 자체를 기록
      _nameFetchedAttemptedForNumbers.add(number);
      log('[CallStateProvider] Marked $number as name fetch attempted.');

      String fetchedName = await contactsController.getContactName(number);
      if (fetchedName.isNotEmpty) {
        if (_callerName != fetchedName) {
          _callerName = fetchedName;
          log(
            '[CallStateProvider] Fetched and updated callerName to: $fetchedName for $number',
          );

          // 이름이 업데이트되면 현재 표시 중인 노티피케이션도 업데이트
          if (_callState == CallState.incoming) {
            try {
              await LocalNotificationService.showIncomingCallNotification(
                phoneNumber: number,
                callerName: fetchedName,
              );
              log(
                '[CallStateProvider] Updated incoming call notification with new name: $fetchedName',
              );
            } catch (e) {
              log(
                '[CallStateProvider] Error updating notification with new name: $e',
              );
            }
          }

          notifyListeners(); // 이름이 실제로 변경되었으므로 알림
        }
      } else {
        log(
          '[CallStateProvider] Fetched name is empty for $number. _callerName remains: "$_callerName"',
        );
      }
    } catch (e) {
      log('[CallStateProvider] Error fetching caller name for $number: $e');
      // 에러 발생 시에도 해당 번호에 대한 조회 시도는 한 것으로 간주 (반복 방지)
    } finally {
      _currentlyFetchingNameForNumber = null;
    }
  }

  // 팝업 토글 메소드 (UI에서 호출)
  void togglePopup() {
    _isPopupVisible = !_isPopupVisible;
    notifyListeners();
  }

  // Ended 상태 후 Idle 전환 타이머 시작 (수정)
  void _startEndedStateTimer() {
    _cancelEndedStateTimer();
    _endedCountdownSeconds = 10;
    _endedStateTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (_callState != CallState.ended) {
        timer.cancel();
        _endedStateTimer = null;
        return;
      }

      // 타이머가 동작하기 전에 활성/대기/수신 통화가 있는지 확인
      final callDetails = await NativeMethods.getCurrentCallState();
      final activeState = callDetails['active_state'] as String? ?? 'IDLE';
      final activeNumber = callDetails['active_number'] as String?;
      final holdingState = callDetails['holding_state'] as String? ?? 'IDLE';
      final holdingNumber = callDetails['holding_number'] as String?;
      final ringingState = callDetails['ringing_state'] as String? ?? 'IDLE';
      final ringingNumber = callDetails['ringing_number'] as String?;
      
      // 활성, 대기, 수신 통화 중 하나라도 있으면 ended 상태 타이머 취소
      final bool hasAnyCall = 
          (activeState == 'ACTIVE' && activeNumber != null && activeNumber.isNotEmpty) ||
          (holdingState == 'HOLDING' && holdingNumber != null && holdingNumber.isNotEmpty) ||
          (ringingState == 'RINGING' && ringingNumber != null && ringingNumber.isNotEmpty);
      
      if (hasAnyCall) {
        log('[CallStateProvider] 활성/대기/수신 통화가 있어 ended 상태에서 복구합니다.');
        timer.cancel();
        _endedStateTimer = null;
        
        // 활성 통화가 있으면 active 상태로, 없으면 대기 또는 수신 통화 상태로 업데이트
        if (activeState == 'ACTIVE' && activeNumber != null && activeNumber.isNotEmpty) {
          await updateCallState(
            state: CallState.active,
            number: activeNumber,
            isConnected: true,
          );
        } else if (holdingState == 'HOLDING' && holdingNumber != null && holdingNumber.isNotEmpty) {
          // 대기 통화가 있으면 활성화
          await NativeMethods.switchCalls(); // 대기 통화를 활성화
          await syncCallState();
        } else if (ringingState == 'RINGING' && ringingNumber != null && ringingNumber.isNotEmpty) {
          // 수신 통화가 있으면 incoming 상태로 업데이트
          await updateCallState(
            state: CallState.incoming,
            number: ringingNumber,
          );
        }
        return;
      }

      if (_endedCountdownSeconds > 0) {
        _endedCountdownSeconds--;
        notifyListeners(); // <<< UI 업데이트 알림
      } else {
        timer.cancel();
        _endedStateTimer = null;
        updateCallState(state: CallState.idle); // idle 상태로 변경
      }
    });
  }

  // Ended 상태 타이머 취소 (수정)
  void _cancelEndedStateTimer() {
    if (_endedStateTimer?.isActive ?? false) {
      _endedStateTimer!.cancel();
    }
    _endedStateTimer = null;
    _endedCountdownSeconds = 10; // <<< 카운트다운 리셋
  }

  // <<< 버튼 상태 토글 메소드 (NativeMethods 호출 추가) >>>
  Future<void> toggleMute() async {
    final newState = !_isMuted;
    try {
      await NativeMethods.toggleMute(newState);
      _isMuted = newState;
      notifyListeners();
    } catch (e) {
      log('[Provider] Error toggling mute: $e');
    }
  }

  Future<void> toggleHold() async {
    final newState = !_isHold;
    try {
      await NativeMethods.toggleHold(newState);
      _isHold = newState;
      notifyListeners();
    } catch (e) {
      log('[Provider] Error toggling hold: $e');
    }
  }

  Future<void> toggleSpeaker() async {
    final newState = !_isSpeakerOn;
    try {
      await NativeMethods.toggleSpeaker(newState);
      _isSpeakerOn = newState;
      notifyListeners();
    } catch (e) {
      log('[Provider] Error toggling speaker: $e');
    }
  }

  // 버튼 상태 초기화 메소드
  void resetButtonStates() {
    if (_isMuted || _isHold || _isSpeakerOn) {
      _isMuted = false;
      _isHold = false;
      _isSpeakerOn = false;
      notifyListeners(); // 상태 변경 알림
    }
  }

  // <<< 근접 센서 리스너 시작 함수 >>>
  void _startProximityListener() {
    // 이전 구독이 있다면 취소
    _proximitySensorSubscription?.cancel();
    try {
      _proximitySensorSubscription = ProximitySensor.events.listen((int event) {
        // event 값이 0보다 크면 가까움(near), 아니면 멂(far)
        bool isNear = event > 0;
        log(
          '[Provider] Proximity Sensor Event: $event -> isNear: $isNear',
        ); // <<< 로그 추가
      });
    } catch (e) {
      log('[Provider] Error starting proximity listener: $e');
    }
  }

  // <<< 근접 센서 리스너 중지 함수 >>>
  void _stopProximityListener() {
    _proximitySensorSubscription?.cancel();
    _proximitySensorSubscription = null;
  }

  // 마지막 리셋 이벤트 추적 변수 (중복 방지용)
  String? _lastResetPhoneNumber;
  DateTime _lastResetEventTime = DateTime.fromMillisecondsSinceEpoch(0);

  // 리셋 이벤트 핸들러
  void _handleResetEvent(CallSearchResetEvent event) {
    log('[CallStateProvider][CRITICAL] 검색 데이터 리셋 이벤트 수신: ${event.phoneNumber}, isWaitingCall: ${event.isWaitingCall}');

    // 이벤트에 전화번호가 포함된 경우 (실제 전화 이벤트)
    if (event.phoneNumber.isNotEmpty) {
      // 중복 이벤트 방지 (1초 이내의 동일 번호 이벤트는 무시)
      final now = DateTime.now();
      final timeDiff = now.difference(_lastResetEventTime).inSeconds;
      if (_lastResetPhoneNumber == event.phoneNumber && timeDiff < 1) {
        log('[CallStateProvider] 중복된 리셋 이벤트 무시 ($timeDiff초 이내): ${event.phoneNumber}');
        return;
      }
      
      // 마지막 처리 정보 업데이트
      _lastResetPhoneNumber = event.phoneNumber;
      _lastResetEventTime = now;
      
      // 이벤트에 isWaitingCall이 true로 설정되어 있거나, 실제 대기 통화 상황인지 확인
      final bool isWaitingCall = event.isWaitingCall || 
                              (_callState == CallState.active && 
                               (_holdingCallNumber != null || _ringingCallNumber != null));
      
      // 대기 통화 상황에서는 상태 초기화 하지 않음
      if (isWaitingCall) {
        // 대기 통화 상황에서 발신자 정보만 초기화
        log('[CallStateProvider] 대기 통화 상황에서 검색 데이터만 초기화 (상태 유지)');
        
        // 대기 통화 번호에 대한 정보만 초기화 (상태는 유지)
        if (event.phoneNumber == _ringingCallNumber) {
          log('[CallStateProvider] 대기 통화 수신 번호에 대한 정보 초기화: ${event.phoneNumber}');
        }
        return;  // 더 이상 진행하지 않음 (상태 변경 방지)
      }
      
      // 현재 표시 중인 번호와 다른 번호가 들어온 경우 전체 상태 리셋 판단
      if (_number.isNotEmpty && event.phoneNumber != _number) {
        // 활성 통화 중에는 초기화하지 않음
        if (_callState != CallState.active) {
          log('[CallStateProvider][CRITICAL] 기존 번호($_number)와 다른 새 번호(${event.phoneNumber}) 감지. 상태 리셋.');
          resetState();
        } else {
          log('[CallStateProvider] 활성 통화 중 다른 번호 이벤트, 상태 유지: $_number, 이벤트: ${event.phoneNumber}');
          return; // 활성 통화 중에는 기존 상태 유지
        }
      }

      // 새 전화 상태로 업데이트 (상태 증진)
      log('[CallStateProvider][CRITICAL] 새 전화 번호 감지. 통화 상태 업데이트 시작');

      // 현재 상태에 따라 적절한 다음 상태로 전환
      if (_callState == CallState.idle || _callState == CallState.ended) {
        // 현재 앱이 foreground에서 실행 중이고 전화가 감지된 경우
        // Native 통화 상태에 따라 결정 (기본값은 INCOMING으로 설정)
        final newState = CallState.incoming;

        // 번호는 이벤트에서 온 번호로 설정
        updateCallState(
          state: newState,
          number: event.phoneNumber,
          callerName: '', // 이름은 비워두고 나중에 조회
          isConnected: false, // 초기에는 연결되지 않은 것으로 설정
        );

        // 팝업 표시를 통해 UI에 즉시 반영
        _isPopupVisible = true;

        log(
          '[CallStateProvider] 통화 상태 업데이트됨: $_callState, 번호: ${event.phoneNumber}, 팝업: $_isPopupVisible',
        );
      }
    } else if (!event.isWaitingCall) {
      // 빈 번호의 이벤트인 경우 (일반적인 초기화 요청), isWaitingCall이 true가 아닌 경우에만 초기화
      log('[CallStateProvider][CRITICAL] 전체 상태 명시적 초기화');
      resetState();
    }
  }

  // 상태 리셋 메서드
  void resetState() {
    log('[CallStateProvider][CRITICAL] 전체 상태 명시적 초기화');

    // 이전 상태 로깅
    if (_callState != CallState.idle) {
      log('[CallStateProvider] 통화 중 상태에서 리셋 - 이전 상태: $_callState');
    }

    // 상태를 명시적으로 IDLE로 설정
    _callState = CallState.idle;
    
    // 이름 조회 관련 변수 초기화
    _nameFetchedAttemptedForNumbers.clear();
    _currentlyFetchingNameForNumber = null;

    // 기본 변수 초기화
    _number = '';
    _callerName = '';
    _duration = 0;
    _isConnected = false;
    _callEndReason = '';
    
    // 대기 및 수신 통화 정보 초기화
    _holdingCallNumber = null;
    _holdingCallerName = null;
    _ringingCallNumber = null;
    _ringingCallerName = null;

    // 버튼 상태 초기화
    resetButtonStates();

    // 타이머 취소 (있다면)
    _cancelEndedStateTimer();

    notifyListeners();
    log('[CallStateProvider] 상태 초기화 완료 및 리스너 알림');
  }

  // 앱 종료 등 리소스 해제 시 타이머 및 센서 리스너 정리
  @override
  void dispose() {
    _cancelEndedStateTimer();
    _stopProximityListener(); // <<< dispose 시 리스너 중지 추가
    contactsController.removeListener(_onContactsUpdated); // <<< 리스너 제거
    _resetEventSubscription?.cancel(); // 리셋 이벤트 구독 취소
    super.dispose();
  }
}
