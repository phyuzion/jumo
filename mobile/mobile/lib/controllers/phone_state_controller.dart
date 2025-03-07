// lib/controllers/phone_state_controller.dart
import 'dart:async';
import 'dart:developer';
import 'package:phone_state/phone_state.dart';
import 'package:mobile/controllers/call_log_controller.dart'; // 예: callLogController

class PhoneStateController {
  StreamSubscription<PhoneState>? _subscription;

  // 통화기록 컨트롤러 (주입 or 싱글턴)
  final callLogController = CallLogController();

  void startListening() {
    _subscription = PhoneState.stream.listen((PhoneState event) {
      switch (event.status) {
        case PhoneStateStatus.NOTHING:
          _onNothing();
          break;
        case PhoneStateStatus.CALL_INCOMING:
          _onIncoming(event.number);
          break;
        case PhoneStateStatus.CALL_STARTED:
          _onCallStarted(event.number);
          break;
        case PhoneStateStatus.CALL_ENDED:
          _onCallEnded();
          break;
      }
    });
  }

  void stopListening() {
    _subscription?.cancel();
    _subscription = null;
  }

  void _onNothing() {
    log('[PhoneState] status: NOTHING');
  }

  void _onIncoming(String? incomingNumber) {
    log('[PhoneState] Incoming: $incomingNumber');
  }

  void _onCallStarted(String? number) {
    log('[PhoneState] CallStarted: $number');
  }

  Future<void> _onCallEnded() async {
    log('[PhoneState] CallEnded');
    // 통화가 종료된 직후 => 새 통화 기록이 system DB에 반영됐을 가능성 높음
    // => callLogController.refreshCallLogsWithDiff() 로 새 로그 업데이트
    final newLogs = await callLogController.refreshCallLogsWithDiff();
    if (newLogs.isNotEmpty) {
      log('[PhoneState] New call logs => ${newLogs.length}');
      // TODO: UI update?
      // ex) using a Stream/Provider to notify RecentScreen or etc.
    }
  }
}
