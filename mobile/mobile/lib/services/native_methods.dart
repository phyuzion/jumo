import 'package:flutter/services.dart';

class NativeMethods {
  static const _channel = MethodChannel('com.jumo.mobile/native');

  /// 안드로이드 → Flutter 이벤트를 받기 위해
  /// Dart 쪽에서 setMethodCallHandler를 등록할 수 있도록 노출
  static void setMethodCallHandler(
    Future<dynamic> Function(MethodCall call) handler,
  ) {
    _channel.setMethodCallHandler(handler);
  }

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
