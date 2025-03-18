import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:mobile/services/native_methods.dart';
import 'package:mobile/services/blocked_numbers_service.dart';

class NavigationController {
  static final navKey = GlobalKey<NavigatorState>();
  static final _blockedNumbersService = BlockedNumbersService();

  static Future<void> init() async {
    // 네이티브 -> Flutter 이벤트 핸들러
    NativeMethods.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onIncomingNumber':
          final number = call.arguments as String;
          // 차단된 번호인지 확인
          if (_blockedNumbersService.isNumberBlocked(number)) {
            // 차단된 번호면 전화 거절
            log('차단된 번호: $number');
            await NativeMethods.rejectCall();
            return;
          }
          goToIncoming(number);
          break;
        case 'onCall':
          final map = call.arguments as Map?; // or Map<String,dynamic>
          if (map != null) {
            final number = map['number'] as String? ?? '';
            final connected = map['connected'] as bool? ?? false;
            // 사용 로직
            goToOnCall(number, connected);
          }
          break;
        case 'onCallEnded':
          final map = call.arguments as Map?; // or Map<String,dynamic>
          if (map != null) {
            final endedNumber = map['number'] as String? ?? '';
            final reason = map['reason'] as String? ?? '';
            // 사용 로직
            goToCallEnded(endedNumber, reason);
          }
          break;
      }
    });
  }

  static void goToDecider() {
    // 기본 전화앱 시나리오에서 수신
    final ctx = navKey.currentContext;
    if (ctx == null) return;
    // "pushNamed"로 -> 뒤로가기 시 이전화면
    Navigator.of(ctx).pushReplacementNamed('/decider');
  }

  static void goToIncoming(String number) {
    // 기본 전화앱 시나리오에서 수신
    final ctx = navKey.currentContext;
    if (ctx == null) return;
    // "pushNamed"로 -> 뒤로가기 시 이전화면
    Navigator.of(ctx).pushNamed('/incoming', arguments: number);
  }

  static void goToOnCall(String number, bool connected) {
    // 기본 전화앱 시나리오에서 수신
    final ctx = navKey.currentContext;
    if (ctx == null) return;
    // "pushNamed"로 -> 뒤로가기 시 이전화면
    Navigator.of(ctx).pushReplacementNamed(
      '/onCall',
      arguments: {'number': number, 'connected': connected},
    );
  }

  static void goToCallEnded(String endedNumber, String reason) {
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
