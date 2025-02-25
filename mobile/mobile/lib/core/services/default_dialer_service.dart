// lib/core/services/default_dialer_service.dart

import 'dart:io';
import 'dart:developer';
import 'package:flutter/services.dart';

class DefaultDialerService {
  static const MethodChannel _channel = MethodChannel('custom.dialer.channel');

  static Future<void> setDefaultDialer() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('setDefaultDialer');
      log('Success to set default dialer');
    } catch (e) {
      log('Failed to set default dialer: $e');
    }
  }

  static Future<bool> isDefaultDialer() async {
    if (!Platform.isAndroid) return true; // iOS는 해당 없음
    try {
      final bool? result = await _channel.invokeMethod<bool>('isDefaultDialer');

      if (result == false) {
        log('Failed to check default dialer');
      } else {
        log('Success to check default dialer');
      }
      return result ?? false;
    } catch (e) {
      log('Failed to check default dialer: $e');
      return false;
    }
  }
}
