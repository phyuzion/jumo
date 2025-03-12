import 'package:flutter/material.dart';
import 'package:mobile/services/native_methods.dart';

class NavigationController {
  static final navKey = GlobalKey<NavigatorState>();

  static Future<void> init() async {
    // 네이티브 -> Flutter 이벤트 핸들러
    NativeMethods.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onIncomingNumber':
          _goToIncoming(call.arguments as String);
          break;
        case 'onCall':
          _goToOnCall(call.arguments as String);
          break;
        case 'onCallEnded':
          final map = call.arguments as Map?; // or Map<String,dynamic>
          if (map != null) {
            final endedNumber = map['number'] as String? ?? '';
            final reason = map['reason'] as String? ?? '';
            // 사용 로직
            _goToCallEnded(endedNumber, reason);
          }
          break;
      }
    });
  }

  static void _goToIncoming(String number) {
    // 기본 전화앱 시나리오에서 수신
    final ctx = navKey.currentContext;
    if (ctx == null) return;
    // "pushNamed"로 -> 뒤로가기 시 이전화면
    Navigator.of(ctx).pushNamed('/incoming', arguments: number);
  }

  static void _goToOnCall(String number) {
    // 기본 전화앱 시나리오에서 수신
    final ctx = navKey.currentContext;
    if (ctx == null) return;
    // "pushNamed"로 -> 뒤로가기 시 이전화면
    Navigator.of(ctx).pushReplacementNamed('/onCall', arguments: number);
  }

  static void _goToCallEnded(String endedNumber, String reason) {
    // 기본 전화앱 시나리오에서 종료
    final ctx = navKey.currentContext;
    if (ctx == null) return;
    // 종료화면은 OnCall→CallEnded 치환이 일반적 → pushReplacementNamed

    Navigator.of(ctx).pushReplacementNamed(
      '/callEnded',
      arguments: {'number': endedNumber, 'reason': reason},
    );
  }
}
