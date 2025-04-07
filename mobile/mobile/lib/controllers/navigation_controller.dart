import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mobile/services/native_methods.dart';
import 'package:mobile/controllers/blocked_numbers_controller.dart';
import 'package:mobile/controllers/call_log_controller.dart';

class NavigationController {
  static final navKey = GlobalKey<NavigatorState>();

  static Future<void> init(
    BlockedNumbersController blockedNumbersController,
  ) async {
    // 네이티브 -> Flutter 이벤트 핸들러
    NativeMethods.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onIncomingNumber':
          final number = call.arguments as String;
          // 차단된 번호인지 비동기 확인
          if (await blockedNumbersController.isNumberBlockedAsync(
            number,
            addHistory: true,
          )) {
            // 차단된 번호면 전화 거절
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

            // 차단된 번호인지 비동기 확인
            if (await blockedNumbersController.isNumberBlockedAsync(
              endedNumber,
              addHistory: false, // 통화 종료 시에는 이력 추가 안 함
            )) {
              // 차단된 번호였으면 콜로그만 업데이트하고 종료 화면 안 감
              final ctx = navKey.currentContext;
              if (ctx != null) {
                final callLogController = ctx.read<CallLogController>();
                // refreshCallLogs는 비동기일 수 있으므로 await 추가 (구현 확인 필요)
                await callLogController.refreshCallLogs();
              }
              return;
            }

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
