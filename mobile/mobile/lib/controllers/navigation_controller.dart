// lib/controllers/navigation_controller.dart
import 'package:flutter/material.dart';
import 'package:mobile/services/native_methods.dart';

class NavigationController {
  static final GlobalKey<NavigatorState> navKey = GlobalKey<NavigatorState>();

  /// 채널 핸들러 등록. 수신전화(onIncomingNumber), 통화종료(onCallEnded) 등
  static Future<void> init() async {
    NativeMethods.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onIncomingNumber':
          final number = call.arguments as String;
          _goToIncomingScreen(number);
          break;
        case 'onCallEnded':
          _goToCallEnded();
          break;
      }
    });
  }

  static void _goToIncomingScreen(String number) {
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
