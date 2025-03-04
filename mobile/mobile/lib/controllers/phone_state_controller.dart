// lib/controllers/phone_state_controller.dart
import 'dart:async';
import 'dart:developer';
import 'package:phone_state/phone_state.dart';

class PhoneStateController {
  StreamSubscription<PhoneState>? _subscription;

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

  /// 전화 상태 리스닝 중지
  void stopListening() {
    _subscription?.cancel();
    _subscription = null;
  }

  void _onNothing() {
    log('phone status Nothing');
  }

  void _onIncoming(String? incomingNumber) {
    log('phone status Incoming: $incomingNumber');
  }

  void _onCallStarted(String? number) {
    log('phone status CallStarted: $number');
  }

  void _onCallEnded() {
    log('phone status CallEnded');
  }
}
