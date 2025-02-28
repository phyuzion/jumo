// lib/services/native_default_dialer_methods.dart
import 'package:flutter/services.dart';

class NativeDefaultDialerMethods {
  static const MethodChannel _channel = MethodChannel(
    'com.jumo.mobile/nativeDefaultDialer',
  );

  static Future<bool> isDefaultDialer() async {
    final res = await _channel.invokeMethod<bool>('isDefaultDialer');
    return res ?? false;
  }

  static Future<bool> requestDefaultDialerManually() async {
    final ok = await _channel.invokeMethod<bool>(
      'requestDefaultDialerManually',
    );
    return ok ?? false;
  }
}
