// lib/services/native_methods.dart
import 'package:flutter/services.dart';

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
}
