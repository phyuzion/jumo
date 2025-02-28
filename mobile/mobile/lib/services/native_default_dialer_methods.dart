// lib/services/native_default_dialer_methods.dart

import 'package:flutter/services.dart';

class NativeDefaultDialerMethods {
  static const MethodChannel _channel = MethodChannel(
    'com.jumo.mobile/nativeDefaultDialer',
  );

  /// 메인액티비티가 보유한 "isDefaultDialer" 로직을 호출
  static Future<bool> isDefaultDialer() async {
    final result = await _channel.invokeMethod<bool>('isDefaultDialer');
    return result ?? false;
  }

  /// 메인액티비티의 "requestDefaultDialerManually" 를 호출
  /// - 내부에서 checkCallPermission -> requestSetDefaultDialer
  /// - 성공 시 true, 거부 or 실패시 false
  static Future<bool> requestDefaultDialerManually() async {
    final ok = await _channel.invokeMethod<bool>(
      'requestDefaultDialerManually',
    );
    return ok ?? false;
  }
}
