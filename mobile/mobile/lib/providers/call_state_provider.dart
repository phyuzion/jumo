import 'dart:async';
import 'dart:developer';
import 'package:flutter/foundation.dart';
import 'package:mobile/controllers/phone_state_controller.dart';

// 통화 상태 enum 정의 (HomeScreen에서 가져옴 - 여기서 관리하는 것이 더 적절)
enum CallState { idle, incoming, active, ended }

class CallStateProvider with ChangeNotifier {
  final PhoneStateController phoneStateController;

  CallState _callState = CallState.idle;
  String _number = '';
  String _callerName = '';
  int _duration = 0;
  bool _isConnected = false; // active 상태 내 연결 여부
  bool _isPopupVisible = false;
  String _callEndReason = ''; // 통화 종료 이유 (missed 등)

  Timer? _callTimer;
  Timer? _endedStateTimer; // ended 상태 후 idle 전환 타이머

  // Getters
  CallState get callState => _callState;
  String get number => _number;
  String get callerName => _callerName;
  int get duration => _duration;
  bool get isConnected => _isConnected;
  bool get isPopupVisible => _isPopupVisible;
  String get callEndReason => _callEndReason;

  // 생성자 수정
  CallStateProvider(this.phoneStateController);

  // 상태 업데이트 메소드 수정
  void updateCallState({
    required CallState state,
    String number = '',
    String callerName = '',
    bool isConnected = false,
    String reason = '',
  }) {
    log(
      '[Provider] Received update: $state, Num: $number, Name: $callerName, Connected: $isConnected, Reason: $reason',
    );

    // 이름 조회 로직 추가
    String finalCallerName = callerName;
    bool shouldFetchName =
        (state == CallState.incoming || state == CallState.active) &&
        number.isNotEmpty &&
        (callerName.isEmpty || callerName == '알 수 없음');

    // 상태 변경 확인 (이름 제외)
    bool stateChanged =
        _callState != state ||
        _number != number ||
        _isConnected != isConnected ||
        _callEndReason != reason;

    // 이름 조회 필요 시 또는 상태 변경 시 업데이트
    if (shouldFetchName || stateChanged) {
      _callState = state;
      _number = number;
      _isConnected = isConnected;
      _callEndReason = reason;
      _callerName = finalCallerName; // 일단 받은 이름으로 설정 (비어있을 수 있음)

      // 상태에 따른 팝업 및 타이머 관리
      if (_callState == CallState.incoming ||
          (_callState == CallState.active)) {
        _isPopupVisible = true; // 전화 오거나 통화 중이면 팝업 자동 표시
        if (_callState == CallState.active && _isConnected) {
          _startCallTimer();
        } else {
          _stopCallTimer(); // incoming 또는 active(ringing) 상태면 타이머 중지/리셋
          _duration = 0; // active(ringing) 상태일 때 시간 0으로 표시
        }
        _cancelEndedStateTimer(); // ended 타이머 취소
      } else if (_callState == CallState.ended) {
        _stopCallTimer();
        // _isPopupVisible = true; // 종료 시 팝업 유지? (선택 사항)
        _isPopupVisible = false; // 종료 시 팝업 즉시 닫기 (현재 HomeScreen 테스트 로직 기준)
        _startEndedStateTimer(); // idle 전환 타이머 시작
      } else {
        // idle
        _stopCallTimer();
        _isPopupVisible = false; // idle이면 팝업 닫기
        _cancelEndedStateTimer();
        // idle 상태일 때 number, callerName 초기화 (선택적)
        // _number = '';
        // _callerName = '';
      }

      notifyListeners(); // 1차 알림 (이름 조회 전)

      // 이름 비동기 조회 및 2차 알림
      if (shouldFetchName) {
        _fetchAndUpdateCallerName(number);
      }
    } else if (state == CallState.active && _callState == CallState.active) {
      // active 상태 지속 시 타이머 업데이트를 위한 notify
      // (만약 _startCallTimer 내부에서 notify를 이미 한다면 이 부분 불필요)
      // notifyListeners();
    }
  }

  // 이름 비동기 조회 및 업데이트 함수
  Future<void> _fetchAndUpdateCallerName(String number) async {
    log('[Provider] Fetching caller name for $number...');
    try {
      String fetchedName = await phoneStateController.getContactName(number);
      if (fetchedName.isNotEmpty && _callerName != fetchedName) {
        log('[Provider] Caller name updated: $fetchedName');
        _callerName = fetchedName;
        notifyListeners(); // 이름 업데이트 후 다시 알림
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

  // 통화 시간 타이머 시작
  void _startCallTimer() {
    _stopCallTimer(); // 이전 타이머 정리
    _duration = 0;
    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_callState == CallState.active && _isConnected) {
        _duration++;
        notifyListeners(); // 매초 시간 업데이트 알림
      } else {
        timer.cancel(); // 상태 변경 시 자동 중지
      }
    });
    log('[Provider] Call timer started.');
  }

  // 통화 시간 타이머 중지
  void _stopCallTimer() {
    if (_callTimer?.isActive ?? false) {
      _callTimer!.cancel();
      log('[Provider] Call timer stopped.');
    }
    _callTimer = null;
    // _duration = 0; // Stop 시 시간 초기화는 updateCallState에서 관리
  }

  // Ended 상태 후 Idle 전환 타이머 시작
  void _startEndedStateTimer() {
    _cancelEndedStateTimer(); // 이전 타이머 취소
    log('[Provider] Starting ended state timer (10 seconds)...');
    _endedStateTimer = Timer(const Duration(seconds: 10), () {
      log('[Provider] Ended state timer finished. Reverting to idle.');
      if (_callState == CallState.ended) {
        // 타이머 도중 상태 변경 방지
        updateCallState(state: CallState.idle); // idle 상태로 변경
      }
    });
  }

  // Ended 상태 타이머 취소
  void _cancelEndedStateTimer() {
    if (_endedStateTimer?.isActive ?? false) {
      _endedStateTimer!.cancel();
      log('[Provider] Canceled ended state timer.');
    }
    _endedStateTimer = null;
  }

  // 앱 종료 등 리소스 해제 시 타이머 정리
  @override
  void dispose() {
    _stopCallTimer();
    _cancelEndedStateTimer();
    super.dispose();
  }
}
