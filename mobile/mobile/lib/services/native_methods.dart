// lib/services/native_methods.dart
import 'package:flutter/services.dart';
import 'dart:developer';

class NativeMethods {
  static const _channel = MethodChannel('com.jumo.mobile/native');

  static void setMethodCallHandler(
    Future<dynamic> Function(MethodCall call) handler,
  ) {
    _channel.setMethodCallHandler(handler);
  }

  static Future<String> getMyPhoneNumber() async {
    final result = await _channel.invokeMethod<String>('getMyPhoneNumber');
    return result ?? '';
  }

  static Future<void> makeCall(String phoneNumber) async {
    if (await _channel.invokeMethod('makeCall', {
      'phoneNumber': phoneNumber,
    })) {}
  }

  static Future<void> openSmsApp(String phoneNumber) async {
    if (await _channel.invokeMethod('openSmsApp', {
      'phoneNumber': phoneNumber,
    })) {}
  }

  static Future<void> acceptCall() async {
    await _channel.invokeMethod('acceptCall');
  }

  static Future<void> rejectCall() async {
    await _channel.invokeMethod('rejectCall');
  }

  static Future<void> hangUpCall() async {
    await _channel.invokeMethod('hangUpCall');
  }

  static Future<void> toggleMute(bool muteOn) async {
    await _channel.invokeMethod('toggleMute', {'muteOn': muteOn});
  }

  static Future<void> toggleHold(bool holdOn) async {
    await _channel.invokeMethod('toggleHold', {'holdOn': holdOn});
  }

  static Future<void> toggleSpeaker(bool speakerOn) async {
    await _channel.invokeMethod('toggleSpeaker', {'speakerOn': speakerOn});
  }

  static Future<Map<String, dynamic>> getCurrentCallState() async {
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'getCurrentCallState',
      );
      return result ?? {'state': 'IDLE', 'number': null};
    } catch (e) {
      log('Error calling getCurrentCallState: $e');
      return {'state': 'IDLE', 'number': null};
    }
  }
}
