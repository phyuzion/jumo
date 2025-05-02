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

// 통화 상태 enum 정의 (HomeScreen에서 가져옴 - 여기서 관리하는 것이 더 적절)
enum CallState { idle, incoming, active, ended }

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

  // <<< 버튼 상태 변수 추가 >>>
  bool _isMuted = false;
  bool _isHold = false;
  bool _isSpeakerOn = false;

  Timer? _endedStateTimer;
  int _endedCountdownSeconds = 10; // <<< 카운트다운 변수 추가

  // <<< 근접 센서 스트림 구독 관리를 위한 변수 추가 >>>
  StreamSubscription<dynamic>? _proximitySensorSubscription;

  // Getters
  CallState get callState => _callState;
  String get number => _number;
  String get callerName => _callerName;
  int get duration => _duration;
  bool get isConnected => _isConnected;
  bool get isPopupVisible => _isPopupVisible;
  String get callEndReason {
    return _callEndReason;
  }

  bool get isMuted => _isMuted;
  bool get isHold => _isHold;
  bool get isSpeakerOn => _isSpeakerOn;
  int get endedCountdownSeconds => _endedCountdownSeconds; // <<< Getter 추가

  // 생성자 수정: 리스너 등록
  CallStateProvider(
    this.phoneStateController,
    this.callLogController,
    this.contactsController,
  ) {
    contactsController.addListener(_onContactsUpdated); // <<< 리스너 등록
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
    bool shouldFetchName =
        (state == CallState.incoming || state == CallState.active) &&
        number.isNotEmpty &&
        callerName.isEmpty; // <<< 수정
    bool needsNotify = needsCoreUpdate || durationChanged || shouldFetchName;

    // <<< 상태 업데이트 적용 >>>
    if (needsCoreUpdate) {
      _callState = state;
      _number = number;
      _isConnected = isConnected;
      _callEndReason = reason;

      // <<< callerName 업데이트 로직 수정: 빈 문자열 허용 >>>
      _callerName = callerName; // 전달된 값 그대로 사용

      log(
        '[CallStateProvider] State updated: state=$_callState, number=$_number, name=$_callerName',
      );
    }
    if (state == CallState.active) {
      _duration = duration;
    }

    // <<< IDLE 상태 진입 시 정보 초기화 추가 >>>
    if (state == CallState.idle) {
      _number = '';
      _callerName = '';
      _isConnected = false;
      _duration = 0;
      _callEndReason = '';
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
      } else if (state == CallState.ended) {
        _isPopupVisible = true;
        _startEndedStateTimer();
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
      }
    }
    // --- 상태 전환 시 1회성 작업 끝 ---

    // <<< 리스너 호출 및 이름 조회 >>>
    if (needsNotify) {
      notifyListeners();
    }
    // 초기 이름 조회 시도
    if (shouldFetchName) {
      _fetchAndUpdateCallerName(number);
    }
  }

  // 이름 비동기 조회 및 업데이트 함수 (재시도 로직 제거)
  Future<void> _fetchAndUpdateCallerName(String number) async {
    try {
      String fetchedName = await contactsController.getContactName(number);

      // 이름이 실제로 변경되었을 때만 업데이트 및 알림
      if (fetchedName.isNotEmpty && _callerName != fetchedName) {
        _callerName = fetchedName;
        notifyListeners();
      } else {
        log('[Provider] Fetched name is same as current: "$_callerName"');
      }
    } catch (e) {
      log('[Provider] Error fetching caller name: $e');
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
    _endedStateTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_callState != CallState.ended) {
        timer.cancel();
        _endedStateTimer = null;
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

  // 앱 종료 등 리소스 해제 시 타이머 및 센서 리스너 정리
  @override
  void dispose() {
    _cancelEndedStateTimer();
    _stopProximityListener(); // <<< dispose 시 리스너 중지 추가
    contactsController.removeListener(_onContactsUpdated); // <<< 리스너 제거
    super.dispose();
  }
}
