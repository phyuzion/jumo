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
