// lib/core/services/phone_service.dart

import 'dart:developer';
import 'package:flutter/services.dart';
import 'package:get_storage/get_storage.dart' as storage;
import '../controllers/phone_controller.dart';

class PhoneService {
  static const MethodChannel _channel = MethodChannel('com.jumo.mobile/phone');

  /// MethodCallHandler로 네이티브 -> Dart 콜백 처리
  static Future<void> initChannel() async {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onIncomingNumber') {
        final Map? data = call.arguments as Map?;
        if (data != null && data['event'] == 'onIncomingNumber') {
          final incomingNum = data['number'] as String? ?? '';
          log('[PhoneService] Incoming phoneNumber: $incomingNum');

          // PhoneController 등에 전달
          PhoneController().onIncomingNumber(incomingNum);
        }
      }
      return;
    });
  }

  /// 시작 -> PhoneStateListener 등록
  static Future<void> startPhoneStateListener() async {
    try {
      await _channel.invokeMethod('startPhoneStateListener');
    } catch (e) {
      log('Error startPhoneStateListener: $e');
    }
  }

  /// 해제 -> Listen_NONE
  static Future<void> stopPhoneStateListener() async {
    try {
      await _channel.invokeMethod('stopPhoneStateListener');
    } catch (e) {
      log('Error stopPhoneStateListener: $e');
    }
  }

  /// 내 번호 가져오기
  static Future<String?> getMyPhoneNumber() async {
    try {
      final result = await _channel.invokeMethod<String>('getMyPhoneNumber');
      return result;
    } catch (e) {
      log('Error getMyPhoneNumber: $e');
      return null;
    }
  }

  /// 내 번호를 GetStorage에 저장
  static Future<void> storeMyPhoneNumber() async {
    final box = storage.GetStorage();
    final myNum = await getMyPhoneNumber();
    if (myNum != null && myNum.isNotEmpty) {
      await box.write('myPhoneNumber', myNum);
      log('Stored my phoneNumber: $myNum');
    } else {
      log('Could not read phoneNumber or it was empty');
    }
  }
}
