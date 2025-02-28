import 'package:flutter/services.dart';

class NativeMethods {
  static const _channel = MethodChannel('com.jumo.mobile/native');

  static Future<void> makeCall(String phoneNumber) async {
    await _channel.invokeMethod('makeCall', {'phoneNumber': phoneNumber});
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
}
