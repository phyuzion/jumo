// lib/services/native_default_dialer_methods.dart
import 'dart:developer';

import 'package:flutter/services.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:mobile/utils/app_event_bus.dart';

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
    
    // 기본 다이얼러 설정이 성공하면 통화 상태를 초기화
    if (ok == true) {
      log('[NativeDefaultDialerMethods][CRITICAL] 기본 다이얼러 설정 성공, 통화 상태 초기화');
      
      // 빈 문자열로 이벤트를 발생시켜 통화 상태를 초기화
      appEventBus.fire(CallSearchResetEvent(''));
      
      // 백그라운드 서비스에도 알림
      try {
        final service = FlutterBackgroundService();
        if (await service.isRunning()) {
          service.invoke('defaultDialerChanged', {'isDefault': true});
          log('[NativeDefaultDialerMethods] 백그라운드 서비스에 기본 다이얼러 변경 알림 전송 완료');
        }
      } catch (e) {
        log('[NativeDefaultDialerMethods] 백그라운드 서비스 알림 실패: $e');
      }
    }
    
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
