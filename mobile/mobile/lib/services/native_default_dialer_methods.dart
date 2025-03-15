// lib/services/native_default_dialer_methods.dart
import 'dart:developer';

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

  static Future<void> notifyNativeAppInitialized() async {
    const channel = MethodChannel('com.jumo.mobile/nativeDefaultDialer');
    try {
      await channel.invokeMethod('setAppInitialized');
      log("setAppInitialized() done!");
    } catch (e) {
      log("setAppInitialized() error: $e");
    }
  }
}
