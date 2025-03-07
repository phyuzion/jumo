import 'package:flutter/material.dart';
import 'package:mobile/services/native_methods.dart';

class NavigationController {
  static final navKey = GlobalKey<NavigatorState>();

  static Future<void> init() async {
    NativeMethods.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onIncomingNumber':
          _goToIncoming(call.arguments as String);
          break;
        case 'onCallEnded':
          _goToCallEnded(call.arguments as String? ?? '');
          break;
      }
    });
  }

  static void _goToIncoming(String number) {
    final ctx = navKey.currentContext;
    if (ctx == null) return;
    Navigator.of(ctx).pushReplacementNamed('/incoming', arguments: number);
  }

  static void _goToCallEnded(String endedNumber) {
    final ctx = navKey.currentContext;
    if (ctx == null) return;
    Navigator.of(
      ctx,
    ).pushReplacementNamed('/callEnded', arguments: endedNumber);
  }
}
