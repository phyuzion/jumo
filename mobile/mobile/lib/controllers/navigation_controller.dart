// lib/controllers/navigation_controller.dart
import 'package:flutter/material.dart';
import 'package:mobile/services/native_methods.dart';

class NavigationController {
  static final GlobalKey<NavigatorState> navKey = GlobalKey<NavigatorState>();

  static Future<void> init() async {
    NativeMethods.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onIncomingNumber':
          final number = call.arguments as String;
          goToIncomingScreen(number);
          break;
        case 'onCallEnded':
          goToCallEnded();
          break;
      }
    });
  }

  static void goToIncomingScreen(String number) {
    final ctx = navKey.currentContext;
    if (ctx != null) {
      Navigator.of(ctx).pushNamed('/incoming', arguments: number);
    }
  }

  static void goToCallEnded() {
    final ctx = navKey.currentContext;
    if (ctx != null) {
      Navigator.of(ctx).pushNamed('/callEnded');
    }
  }
}
