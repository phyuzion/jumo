import 'dart:async';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:get_storage/get_storage.dart';
import 'package:phone_state/phone_state.dart';
import 'package:mobile/controllers/call_log_controller.dart';
import 'package:mobile/services/native_default_dialer_methods.dart';

class PhoneStateController {
  final GlobalKey<NavigatorState> navKey;
  final CallLogController callLogController;
  PhoneStateController(this.navKey, this.callLogController);

  StreamSubscription<PhoneState>? _subscription;

  bool outgoingCallFromApp = false; // 앱 발신여부

  void startListening() {
    _subscription = PhoneState.stream.listen((event) async {
      switch (event.status) {
        case PhoneStateStatus.NOTHING:
          _onNothing();
          break;
        case PhoneStateStatus.CALL_INCOMING:
          await _onIncoming(event.number);
          break;
        case PhoneStateStatus.CALL_STARTED:
          break;
        case PhoneStateStatus.CALL_ENDED:
          await _onCallEnded(event.number);
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
    final isDef = await NativeDefaultDialerMethods.isDefaultDialer();

    if (!isDef) {
      if (await FlutterOverlayWindow.isActive()) {
        FlutterOverlayWindow.closeOverlay();
      }
      final box = GetStorage();
      await box.write('search_number', number ?? '');
      await FlutterOverlayWindow.showOverlay(
        enableDrag: true,
        alignment: OverlayAlignment.center,
        height: WindowSize.matchParent,
        width: WindowSize.matchParent,
        overlayTitle: "CallResultOverlay",
        overlayContent: "수신전화감지", // 알림 표기용
        flag: OverlayFlag.defaultFlag,
        visibility: NotificationVisibility.visibilityPublic,
        positionGravity: PositionGravity.auto,
      );
    } else {
      log('[PhoneState] default dialer => skip phone_state incoming UI');
    }

    log('[PhoneState] not default => overlay shown for $number');
  }

  Future<void> _onCallEnded(String? number) async {
    log('[PhoneState] callEnded => sync logs');

    callLogController.refreshCallLogs();

    final isDef = await NativeDefaultDialerMethods.isDefaultDialer();
    if (!isDef && outgoingCallFromApp) {
      outgoingCallFromApp = false;
      final state = navKey.currentState;
      if (state != null) {
        final endedNum = number ?? '';
        state.pushReplacementNamed('/callEnded', arguments: endedNum);
      }
    }
  }
}
