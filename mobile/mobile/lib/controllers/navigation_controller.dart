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
        );
      }
      // <<< 로직 이동 끝 >>>

      switch (call.method) {
        case 'onIncomingNumber':
          if (await blockedNumbersController.isNumberBlockedAsync(
            number,
            addHistory: true,
          )) {
            await NativeMethods.rejectCall();
            return;
          }
          goToIncoming(number);
          break;
        case 'onCall':
          final map = call.arguments as Map?;
          if (map != null) {
            final connected = map['connected'] as bool? ?? false;
            goToOnCall(number, connected);
          }
          break;
        case 'onCallEnded':
          final map = call.arguments as Map?;
          if (map != null) {
            final reason = map['reason'] as String? ?? '';

            if (await blockedNumbersController.isNumberBlockedAsync(
              number,
              addHistory: false,
            )) {
              final ctx = navKey.currentContext;
              if (ctx != null) {
                final callLogController = ctx.read<CallLogController>();
                await callLogController.refreshCallLogs();
              }
              return;
            }
            goToCallEnded(number, reason);
          }
          break;
      }
    });
  }

  static void goToDecider() {
    final ctx = navKey.currentContext;
    if (ctx == null) return;
    Navigator.of(ctx).pushReplacementNamed('/decider');
  }

  static void goToIncoming(String number) {
    final ctx = navKey.currentContext;
    if (ctx == null) return;
    Navigator.of(ctx).pushNamed('/incoming', arguments: number);
  }

  static void goToOnCall(String number, bool connected) {
    final ctx = navKey.currentContext;
    if (ctx == null) return;
    Navigator.of(ctx).pushReplacementNamed(
      '/onCall',
      arguments: {'number': number, 'connected': connected},
    );
  }

  static void goToCallEnded(String endedNumber, String reason) {
    final ctx = navKey.currentContext;
    if (ctx == null) return;
    Navigator.of(ctx).pushReplacementNamed(
      '/callEnded',
      arguments: {'number': endedNumber, 'reason': reason},
    );
  }
}
