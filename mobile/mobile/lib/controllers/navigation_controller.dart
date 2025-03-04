// lib/controllers/navigation_controller.dart
import 'package:flutter/material.dart';
import 'package:mobile/services/native_methods.dart';

class NavigationController {
  static final GlobalKey<NavigatorState> navKey = GlobalKey<NavigatorState>();

  static Future<void> init() async {
    NativeMethods.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onIncomingNumber':
          _goToIncoming(call.arguments as String);
          break;
        case 'onCallEnded':
          _goToCallEnded();
          break;
      }
    });
  }

  static void _goToIncoming(String number) {
    final ctx = navKey.currentContext;
    if (ctx != null) {
      Navigator.of(ctx).pushNamed('/incoming', arguments: number);
    }
  }

  static void _goToCallEnded() {
    final ctx = navKey.currentContext;
    if (ctx != null) {
      Navigator.of(ctx).pushNamed('/callEnded');
    }
  }
}
