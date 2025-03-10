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
  bool _isOnCallScreen = false;
  bool _inCall = false;

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
          await _onCallStarted(event.number);
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
    _inCall = true;
    final isDef = await NativeDefaultDialerMethods.isDefaultDialer();
    if (isDef) {
      log('[PhoneState] default dialer => skip phone_state incoming UI');
    } else {
      if (await FlutterOverlayWindow.isActive()) {
        FlutterOverlayWindow.closeOverlay();
      }

      // 2) number 저장
      final box = GetStorage();
      await box.write('search_number', number ?? '');

      // 3) 오버레이 실행
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
        // key: 'overlayMain', => If needed
      );

      log('[PhoneState] not default => overlay shown for $number');
    }
  }

  Future<void> _onCallStarted(String? number) async {
    _inCall = true;

    //이미 들어가 있으면 리턴
    if (_isOnCallScreen) {
      log('[PhoneState] already onCall screen => skip');
      return;
    }

    // 발신 -> OnCall
    _isOnCallScreen = true;

    final phone = number ?? '';
    log('[PhoneState] => pushNamed /onCall($phone)');

    final state = navKey.currentState;
    if (state == null) return;

    if (outgoingCallFromApp) {
      log('안에서 건 애니까 그냥 덮어씌운다.');
      state.pushNamed('/onCall', arguments: phone);
    } else {
      final isDef = await NativeDefaultDialerMethods.isDefaultDialer();
      if (isDef) {
        log('안에서 건애 아니고 기본애니까 덮어씌운다.');
        state.pushReplacementNamed('/onCall', arguments: phone);
      }
    }
  }

  Future<void> _onCallEnded(String? number) async {
    log('[PhoneState] callEnded => sync logs');

    if (!_inCall) {
      // 처음부터 통화중이 아니었다면 => spurious ended
      log('[PhoneState] ignore spurious ended');
      return;
    }
    _inCall = false;
    _isOnCallScreen = false;
    outgoingCallFromApp = false;

    callLogController.refreshCallLogs();

    final isDef = await NativeDefaultDialerMethods.isDefaultDialer();
    if (!isDef) {
      final state = navKey.currentState;
      if (state != null) {
        final endedNum = number ?? '';
        state.pushReplacementNamed('/callEnded', arguments: endedNum);
      }
    }
  }
}
