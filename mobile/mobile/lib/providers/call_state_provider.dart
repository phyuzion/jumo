import 'dart:async';
import 'dart:developer';
import 'package:flutter/foundation.dart';
import 'package:mobile/controllers/phone_state_controller.dart';
import 'package:mobile/services/native_methods.dart';
import 'package:mobile/services/native_default_dialer_methods.dart';
import 'package:mobile/services/local_notification_service.dart';
import 'package:mobile/controllers/call_log_controller.dart';
import 'package:mobile/controllers/contacts_controller.dart';

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

  // Getters
  CallState get callState => _callState;
  String get number => _number;
  String get callerName => _callerName;
  int get duration => _duration;
  bool get isConnected => _isConnected;
  bool get isPopupVisible => _isPopupVisible;
  String get callEndReason {
    log('[Provider] Getting callEndReason: $_callEndReason');
    return _callEndReason;
  }

  bool get isMuted => _isMuted;
  bool get isHold => _isHold;
  bool get isSpeakerOn => _isSpeakerOn;
  int get endedCountdownSeconds => _endedCountdownSeconds; // <<< Getter 추가

  // 생성자 수정
  CallStateProvider(
    this.phoneStateController,
    this.callLogController,
    this.contactsController,
  );

  // 상태 업데이트 메소드 수정 (async 추가)
  Future<void> updateCallState({
    required CallState state,
    String number = '',
    String callerName = '',
    bool isConnected = false,
    String reason = '',
    int duration = 0, // <<< duration 파라미터 추가
  }) async {
    log(
      '[Provider] Received update: $state, Num: $number, Name: $callerName, Connected: $isConnected, Reason: $reason',
    );

    // 이름 조회 필요 여부 확인 (기존 로직)
    String finalCallerName = callerName;
    bool shouldFetchName =
        (state == CallState.incoming || state == CallState.active) &&
        number.isNotEmpty &&
        (callerName.isEmpty || callerName == '알 수 없음');

    // <<< 상태 전환 여부 확인 (duration 제외) >>>
    bool stateTransitioned = _callState != state;
    // <<< 다른 정보 변경 여부 확인 >>>
    bool infoChanged =
        _number != number ||
        _callerName != callerName || // 이름 변경도 고려?
        _isConnected != isConnected ||
        _callEndReason != reason;
    // <<< Duration 변경 여부 >>>
    bool durationChanged = (state == CallState.active && _duration != duration);

    // 상태 업데이트 필요 여부 (상태 전환 또는 주요 정보 변경 시)
    bool needsCoreUpdate = stateTransitioned || infoChanged;
    // UI 업데이트 필요 여부 (위 조건 또는 duration 변경 시)
    bool needsNotify = needsCoreUpdate || durationChanged || shouldFetchName;

    if (!needsNotify) return; // 아무 변경 없으면 종료

    if (needsCoreUpdate) {
      _callState = state;
      _number = number;
      _isConnected = isConnected;
      _callEndReason = reason;
      _callerName = finalCallerName;
    }
    // Duration은 active 상태일 때 항상 업데이트
    if (state == CallState.active) {
      _duration = duration;
    }

    // <<< 팝업/타이머 관리는 상태 *전환* 시에만 수행 >>>
    if (stateTransitioned) {
      log('[Provider] State transitioned from $_callState to $state');
      bool isDefault = await NativeDefaultDialerMethods.isDefaultDialer();
      log('[Provider] Is default dialer: $isDefault');

      if (_callState == CallState.incoming || _callState == CallState.active) {
        if (isDefault) {
          _isPopupVisible = true;
        } else {
          _isPopupVisible = false;
        }
        _cancelEndedStateTimer();
      } else if (_callState == CallState.ended) {
        _isPopupVisible = true;
        _startEndedStateTimer();
        if (_callEndReason == 'missed') {
          log('[Provider] Showing missed call notification for $_number');
          final notificationId = _number.hashCode;
          LocalNotificationService.showMissedCallNotification(
            id: notificationId,
            callerName: _callerName,
            phoneNumber: _number,
          );
        }
        await Future.delayed(const Duration(seconds: 2));
        log('[Provider] Refreshing call logs after call ended.');
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

    notifyListeners(); // 모든 필요한 업데이트 후 한번만 호출

    if (shouldFetchName) {
      _fetchAndUpdateCallerName(number);
    }
  }

  // 이름 비동기 조회 및 업데이트 함수 (수정)
  Future<void> _fetchAndUpdateCallerName(String number) async {
    log('[Provider] Fetching caller name for $number...');
    try {
      String fetchedName = await contactsController.getContactName(number);
      if (fetchedName.isNotEmpty && _callerName != fetchedName) {
        log('[Provider] Caller name updated: $fetchedName');
        _callerName = fetchedName;
        notifyListeners();
      }
    } catch (e) {
      log('[Provider] Error fetching caller name: $e');
    }
  }

  // 팝업 토글 메소드 (UI에서 호출)
  void togglePopup() {
    // TODO: idle 상태일 때만 팝업 토글 허용? 아니면 항상?
    // 현재는 통화 관련 상태일 때만 토글 가능하게 (idle 제외)
    // if (_callState != CallState.idle) {
    _isPopupVisible = !_isPopupVisible;
    log('[Provider] Popup toggled: $_isPopupVisible');
    notifyListeners();
    // }
  }

  // Ended 상태 후 Idle 전환 타이머 시작 (수정)
  void _startEndedStateTimer() {
    _cancelEndedStateTimer();
    _endedCountdownSeconds = 10;
    log('[Provider] Starting ended state countdown timer...');
    _endedStateTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      log(
        '[Provider] Ended Timer Tick! Countdown: $_endedCountdownSeconds, State: $_callState',
      );
      if (_callState != CallState.ended) {
        log('[Provider] State changed during countdown. Cancelling timer.');
        timer.cancel();
        _endedStateTimer = null;
        return;
      }

      if (_endedCountdownSeconds > 0) {
        _endedCountdownSeconds--;
        notifyListeners(); // <<< UI 업데이트 알림
      } else {
        log('[Provider] Countdown finished. Reverting to idle.');
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
      log('[Provider] Canceled ended state timer.');
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
      log('[Provider] Mute toggled: $_isMuted');
      notifyListeners();
    } catch (e) {
      log('[Provider] Error toggling mute: $e');
      // 에러 발생 시 상태 롤백 등 처리?
    }
  }

  Future<void> toggleHold() async {
    final newState = !_isHold;
    try {
      await NativeMethods.toggleHold(newState);
      _isHold = newState;
      log('[Provider] Hold toggled: $_isHold');
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
      log('[Provider] Speaker toggled: $_isSpeakerOn');
      notifyListeners();
    } catch (e) {
      log('[Provider] Error toggling speaker: $e');
    }
  }

  // 앱 종료 등 리소스 해제 시 타이머 정리
  @override
  void dispose() {
    _cancelEndedStateTimer();
    super.dispose();
  }
}
