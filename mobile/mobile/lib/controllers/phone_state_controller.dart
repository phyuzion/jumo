import 'dart:async';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:mobile/services/native_default_dialer_methods.dart';
import 'package:phone_state/phone_state.dart';
import 'package:mobile/controllers/call_log_controller.dart';

class PhoneStateController {
  final GlobalKey<NavigatorState> navKey;
  PhoneStateController(this.navKey);

  StreamSubscription<PhoneState>? _subscription;
  final callLogController = CallLogController();

  bool outgoingCallFromApp = false; // 앱 발신여부
  bool _isOnCallScreen = false;
  bool _inCall = false;

  void startListening() {
    _subscription = PhoneState.stream.listen((event) {
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
          _onCallEnded(event.number);
          break;
      }
    });
  }

  void stopListening() {
    _subscription?.cancel();
    _subscription = null;
  }

  void _onNothing() {
    log('[PhoneState] NOTHING');
  }

  Future<void> _onIncoming(String? number) async {
    //nothing happend.
    _inCall = true;
    if (await NativeDefaultDialerMethods.isDefaultDialer()) {
      log('[PhoneState] inCallService handles => skip');
    } else {
      log('[PhoneState] not default => skip UI');
    }
  }

  Future<void> _onCallStarted(String? number) async {
    _inCall = true;
    if (await NativeDefaultDialerMethods.isDefaultDialer()) {
      log('[PhoneState] default dialer => skip phone_state UI');
      return;
    }
    // 비기본앱 + 앱 발신
    if (outgoingCallFromApp && !_isOnCallScreen) {
      final state = navKey.currentState;
      if (state == null) return;

      _isOnCallScreen = true;
      final phone = number ?? '';
      log('[PhoneState] push /onCall => $phone');
      state.pushNamed('/onCall', arguments: phone);
    }
  }

  Future<void> _onCallEnded(String? number) async {
    log('[PhoneState] callEnded => logs sync');
    if (!_inCall) {
      log('Ignore spurious CALL_ENDED because we were never in call');
      return;
    }
    _inCall = false;
    _isOnCallScreen = false;
    outgoingCallFromApp = false;

    // 갱신
    final newLogs = await callLogController.refreshCallLogsWithDiff();
    if (newLogs.isNotEmpty) {
      log('[PhoneState] new logs => ${newLogs.length}');
    }
    final nav = navKey.currentState;
    nav?.pushReplacementNamed('/callEnded', arguments: number ?? '');
  }
}
