import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:mobile/services/native_methods.dart';
import 'package:mobile/controllers/blocked_numbers_controller.dart';
import 'package:mobile/controllers/phone_state_controller.dart';
import 'package:mobile/services/native_default_dialer_methods.dart';
import 'package:mobile/controllers/contacts_controller.dart';

class NavigationController {
  static final navKey = GlobalKey<NavigatorState>();

  static Future<void> init(
    PhoneStateController phoneStateController,
    BlockedNumbersController blockedNumbersController,
    ContactsController contactsController,
  ) async {
    // 네이티브 -> Flutter 이벤트 핸들러
    NativeMethods.setMethodCallHandler((call) async {
      // <<< 기본 앱 여부 확인 >>>
      final bool isDefault = await NativeDefaultDialerMethods.isDefaultDialer();
      log(
        '[NavigationController] Received native event ${call.method}. Is default: $isDefault',
      );

      // ... (번호 추출 및 이름 조회 로직)
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
        callerName = await contactsController.getContactName(number);
      }

      // <<< 기본 앱일 때만 상태 알림 >>>
      if (isDefault && number.isNotEmpty) {
        log(
          '[NavigationController] Notifying provider (via PhoneStateController) as default app.',
        );
        phoneStateController.notifyServiceCallState(
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
      } else if (!isDefault) {
        log(
          '[NavigationController] Ignoring native event notification because not default app.',
        );
      }

      // <<< 차단 로직은 isDefault 상관없이 필요할 수 있음 (단, reject은 기본 앱일때만 의미있음) >>>
      if (call.method == 'onIncomingNumber' && isDefault) {
        // 기본 앱일때만 네이티브 reject 호출
        if (await blockedNumbersController.isNumberBlockedAsync(
          number,
          addHistory: true,
        )) {
          log(
            '[NavigationController] Incoming call blocked for $number, rejecting call.',
          );
          await NativeMethods.rejectCall();
          // TODO: Optionally notify provider about blocked state?
          return;
        }
      }
      // <<< 기본 앱일 때는 여기서 화면 전환 없음! >>>
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
