import 'dart:async';
import 'dart:developer';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:mobile/services/background_service/service_constants.dart';

class CallTimer {
  final ServiceInstance _service;
  final FlutterLocalNotificationsPlugin _notifications;

  Timer? _callTimer;
  int _ongoingSeconds = 0;
  String _currentNumber = '';
  String _currentCallerName = '';

  CallTimer(this._service, this._notifications);

  // 타이머 상태 접근자
  bool get isActive => _callTimer?.isActive ?? false;
  int get ongoingSeconds => _ongoingSeconds;

  void startCallTimer(String number, String callerName) {
    // 이미 실행 중인 타이머가 있으면 중지
    if (_callTimer?.isActive ?? false) {
      _callTimer!.cancel();
      log('[CallTimer] Existing call timer stopped for restart.');
    }

    // 기존 타이머가 없는 경우에만 초기화
    if (_callTimer == null && _ongoingSeconds == 0) {
      log('[CallTimer] Initializing new call timer with 0 seconds.');
    }

    // 현재 전화번호와 발신자 이름 업데이트
    _currentNumber = number;
    _currentCallerName = callerName;

    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      _ongoingSeconds++;

      // 네이티브 통화 상태 확인
      final nativeCallDetails = await _getCurrentCallStateFromNative();
      if (nativeCallDetails == null) return;

      // 기존 코드: 단일 'state' 필드만 확인
      // final String nativeState = nativeCallDetails['state'] as String? ?? 'UNKNOWN';
      
      // 개선된 코드: active_state, holding_state, ringing_state를 모두 확인
      final String activeState = nativeCallDetails['active_state'] as String? ?? 'IDLE';
      final String holdingState = nativeCallDetails['holding_state'] as String? ?? 'IDLE';
      final String ringingState = nativeCallDetails['ringing_state'] as String? ?? 'IDLE';
      
      final String activeNumber = nativeCallDetails['active_number'] as String? ?? '';
      final String holdingNumber = nativeCallDetails['holding_number'] as String? ?? '';
      final String ringingNumber = nativeCallDetails['ringing_number'] as String? ?? '';
      
      // 활성 통화, 대기 통화, 수신 통화, 발신 통화 중 하나라도 있으면 타이머 계속 유지
      final bool hasAnyCall = 
          ((activeState == 'ACTIVE' || activeState == 'DIALING') && activeNumber.isNotEmpty) ||
          (holdingState == 'HOLDING' && holdingNumber.isNotEmpty) ||
          (ringingState == 'RINGING' && ringingNumber.isNotEmpty);

      if (!hasAnyCall) {
        // 모든 통화가 없는 경우에만 타이머 중지
        log(
          '[CallTimer] No active, holding, or ringing calls detected. Stopping timer.',
        );
        stopCallTimer(); // 타이머 중지

        // UI에 통화 종료 상태 알림
        _service.invoke('updateUiCallState', {
          'state': 'ended',
          'number': _currentNumber, // 여기에 number 추가
          'callerName': '', // 빈 문자열로 변경
          'connected': false,
          'duration': _ongoingSeconds,
          'reason': 'sync_ended_no_calls_detected',
        });

        // 백그라운드 서비스의 'callStateChanged' 리스너에게도 'ended' 상태를 알림
        _service.invoke('callStateChanged', {
          'state': 'ended',
          'number': _currentNumber,
          'callerName': '', // 빈 문자열로 변경
          'connected': false,
          'reason': 'sync_ended_no_calls_detected',
        });
      } else {
        // 활성, 대기, 수신 통화가 있으면 타이머 유지 및 로그 출력
        log(
          '[CallTimer] Call detected: active=$activeState, holding=$holdingState, ringing=$ringingState. Timer continues. Duration: $_ongoingSeconds',
        );

        // 포그라운드 알림 업데이트
        await _updateForegroundNotification();
        
        // 네이티브 활성 번호가 있으면 캐싱된 정보 업데이트
        if (activeState == 'ACTIVE' && activeNumber.isNotEmpty) {
          // 번호가 바뀐 경우에만 로그 출력
          if (_currentNumber != activeNumber) {
            log('[CallTimer] Active call number changed: $_currentNumber -> $activeNumber');
            _currentNumber = activeNumber;
            // 이름 조회 로직 제거
          }
        }

        // UI에 'active' 상태 업데이트 - 네이티브에서 받은 activeNumber 사용
        final bool isDialing = activeState == 'DIALING';
        _service.invoke('updateUiCallState', {
          'state': 'active',
          'number': activeNumber.isNotEmpty ? activeNumber : _currentNumber,
          'callerName': '', // 빈 문자열로 변경
          'connected': !isDialing, // DIALING이면 연결되지 않은 상태로 표시
          'duration': _ongoingSeconds,
          'reason': '',
        });
      }
    });
    log('[CallTimer] Call timer started with native state check.');
  }

  void stopCallTimer() {
    if (_callTimer?.isActive ?? false) {
      _callTimer!.cancel();
      log('[CallTimer] Call timer stopped.');
    }
    _callTimer = null;
    // 통화가 완전히 끝났을 때만 ongoingSeconds 초기화
    _ongoingSeconds = 0;
  }

  Future<void> _updateForegroundNotification() async {
    if (_service is AndroidServiceInstance) {
      final androidService = _service;
      if (await androidService.isForegroundService()) {
        String title = '통화중... (${_formatDuration(_ongoingSeconds)})';
        String content = '$_currentCallerName ($_currentNumber)';
        String payload = 'active:$_currentNumber';

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

  String _formatDuration(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return "$minutes:$secs";
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
      log('[CallTimer] Timeout or error waiting for native state: $e');
      subscription?.cancel();
      return null;
    }
  }
}
