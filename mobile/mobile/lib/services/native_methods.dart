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

  static Future<List<Map<String, dynamic>>> getContacts() async {
    try {
      final List<dynamic> result = await _channel.invokeMethod('getContacts');
      return result.map((contact) {
        final Map<String, dynamic> typedContact = Map<String, dynamic>.from(
          contact,
        );
        // lastUpdated를 DateTime으로 변환 (밀리초 타임스탬프)
        if (typedContact['lastUpdated'] != null) {
          typedContact['lastUpdated'] = DateTime.fromMillisecondsSinceEpoch(
            (typedContact['lastUpdated'] as int),
          );
        }
        return typedContact;
      }).toList();
    } on PlatformException catch (e) {
      log('Error getting contacts: ${e.message}');
      return [];
    }
  }

  static Future<String> upsertContact({
    String? rawContactId,
    required String displayName,
    required String firstName,
    required String middleName,
    required String lastName,
    required String phoneNumber,
  }) async {
    try {
      final String result = await _channel.invokeMethod('upsertContact', {
        'rawContactId': rawContactId,
        'displayName': displayName,
        'firstName': firstName,
        'middleName': middleName,
        'lastName': lastName,
        'phoneNumber': phoneNumber,
      });
      return result;
    } on PlatformException catch (e) {
      log('Error upserting contact: ${e.message}');
      rethrow;
    }
  }

  static Future<bool> deleteContact(String id) async {
    try {
      final bool result = await _channel.invokeMethod('deleteContact', {
        'id': id,
      });
      return result;
    } on PlatformException catch (e) {
      log('Error deleting contact: ${e.message}');
      return false;
    }
  }
}
