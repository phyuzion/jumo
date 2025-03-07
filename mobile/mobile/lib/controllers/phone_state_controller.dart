// lib/controllers/phone_state_controller.dart
import 'dart:async';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:phone_state/phone_state.dart';
import 'package:mobile/controllers/call_log_controller.dart'; // 예: callLogController

class PhoneStateController {
  final GlobalKey<NavigatorState> navKey;

  PhoneStateController(this.navKey);

  StreamSubscription<PhoneState>? _subscription;

  // 통화기록 컨트롤러 (주입 or 싱글턴)
  final callLogController = CallLogController();
  bool _isOnCallScreen = false;

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
    log('[PhoneState] status: NOTHING');
  }

  void _onIncoming(String? incomingNumber) {
    log('[PhoneState] Incoming: $incomingNumber');
  }

  void _onCallStarted(String? number) {
    if (_isOnCallScreen) {
      log('[PhoneState] Already on call screen, skip...');
      return;
    }

    final state = navKey.currentState;
    if (state == null) return;

    // 간단히, routes stack 확인
    bool alreadyOnOnCall = false;
    state.popUntil((route) {
      if (route.settings.name == '/onCall') {
        alreadyOnOnCall = true;
      }
      return true;
    });

    if (alreadyOnOnCall) {
      log('[PhoneState] Already in OnCall route, skip...');
      return;
    }

    _isOnCallScreen = true;

    state.pushReplacementNamed('/onCall', arguments: number ?? '');
  }

  Future<void> _onCallEnded(String? number) async {
    log('[PhoneState] CallEnded');
    _isOnCallScreen = false;

    final state = navKey.currentState;
    if (state == null) return;

    final newLogs = await callLogController.refreshCallLogsWithDiff();
    if (newLogs.isNotEmpty) {
      log('[PhoneState] New call logs => ${newLogs.length}');
      // TODO: UI update?
      // ex) using a Stream/Provider to notify RecentScreen or etc.
    }
  }
}
