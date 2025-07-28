import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:mobile/services/native_methods.dart';
import 'package:mobile/controllers/phone_state_controller.dart';
import 'package:mobile/services/native_default_dialer_methods.dart';
import 'package:mobile/controllers/contacts_controller.dart';

class NavigationController {
  static final navKey = GlobalKey<NavigatorState>();

  static Future<void> init(
    PhoneStateController phoneStateController,
    ContactsController contactsController,
  ) async {
    NativeMethods.setMethodCallHandler((call) async {
      final bool isDefault = await NativeDefaultDialerMethods.isDefaultDialer();
      log(
        '[NavigationController] Received native event ${call.method}. Is default: $isDefault',
      );

      // 기본 전화 앱 설정 변경으로 인한 상태 초기화 이벤트는 별도 처리
      if (call.method == 'onResetCallState') {
        log('[NavigationController] 기본 전화 앱 설정 변경으로 인한 상태 초기화 이벤트 수신');
        // 이 이벤트는 PhoneStateController로 전달하지 않음
        return;
      }

      try {
        phoneStateController.handleNativeEvent(
          call.method,
          call.arguments,
          isDefault,
        );
        log(
          '[NavigationController] Relayed event ${call.method} to PhoneStateController.',
        );
      } catch (e) {
        log(
          '[NavigationController] Error relaying event to PhoneStateController: $e',
        );
      }
    });
  }

  static void goToDecider() {
    final ctx = navKey.currentContext;
    if (ctx == null) return;
    Navigator.of(ctx).pushReplacementNamed('/decider');
  }

  // <<< 다른 goTo... 함수들은 주석 처리 유지 >>>
  // static void goToIncoming(String number) { ... }
  // static void goToOnCall(String number, bool connected) { ... }
  // static void goToCallEnded(String endedNumber, String reason) { ... }
}
