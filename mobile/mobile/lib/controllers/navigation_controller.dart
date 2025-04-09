import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mobile/services/native_methods.dart';
import 'package:mobile/controllers/blocked_numbers_controller.dart';
import 'package:mobile/controllers/call_log_controller.dart';
import 'package:mobile/controllers/phone_state_controller.dart';

class NavigationController {
  static final navKey = GlobalKey<NavigatorState>();

  static Future<void> init(
    PhoneStateController phoneStateController,
    BlockedNumbersController blockedNumbersController,
  ) async {
    // 네이티브 -> Flutter 이벤트 핸들러
    NativeMethods.setMethodCallHandler((call) async {
      // <<< 핸들러 내부로 로직 이동 >>>
      String number = '';
      String callerName = '';
      final callArgs = call.arguments;
      if (callArgs != null) {
        if (callArgs is Map) {
          number = callArgs['number'] as String? ?? '';
        } else if (callArgs is String) {
          number = callArgs;
        }
      }
      if (number.isNotEmpty) {
        callerName = await phoneStateController.getContactName(number);
      }

      // <<< 백그라운드 서비스에 상태 알림 (메소드 이름 변경 필요) >>>
      if (number.isNotEmpty) {
        phoneStateController.notifyServiceCallState(
          // <<< public 메소드 호출
          call.method,
          number,
          callerName,
          connected:
              (call.method == 'onCall' && callArgs is Map)
                  ? (callArgs['connected'] as bool? ?? false)
                  : null,
          reason:
              (call.method == 'onCallEnded' && callArgs is Map)
                  ? (callArgs['reason'] as String? ?? '')
                  : '',
        );
      }
      // <<< 로직 이동 끝 >>>

      // <<< 차단 로직은 여기서 처리? 또는 Provider에서? (우선 유지 후 검토) >>>
      if (call.method == 'onIncomingNumber') {
        if (await blockedNumbersController.isNumberBlockedAsync(
          number,
          addHistory: true,
        )) {
          log(
            '[NavigationController] Incoming call blocked for $number, rejecting call.',
          );
          await NativeMethods.rejectCall();
          return;
        }
      }
    });
  }

  // <<< goToDecider 함수 복원 >>>
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
