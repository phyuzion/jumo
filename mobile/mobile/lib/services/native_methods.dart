// lib/services/native_methods.dart
import 'package:flutter/services.dart';
import 'dart:developer';
import 'dart:async';

class NativeMethods {
  static const _methodChannel = MethodChannel('com.jumo.mobile/native');
  static const _contactsEventChannel = EventChannel(
    'com.jumo.mobile/contactsStream',
  );

  // 네이티브 스트림 구독 관리를 위한 변수
  static StreamSubscription<dynamic>? _nativeContactsStreamSubscription;

  static void setMethodCallHandler(
    Future<dynamic> Function(MethodCall call) handler,
  ) {
    _methodChannel.setMethodCallHandler(handler);
  }

  static Future<String> getMyPhoneNumber() async {
    final result = await _methodChannel.invokeMethod<String>(
      'getMyPhoneNumber',
    );
    return result ?? '';
  }

  static Future<void> makeCall(String phoneNumber) async {
    await _methodChannel.invokeMethod('makeCall', {'phoneNumber': phoneNumber});
  }

  static Future<void> openSmsApp(String phoneNumber) async {
    await _methodChannel.invokeMethod('openSmsApp', {
      'phoneNumber': phoneNumber,
    });
  }

  static Future<void> acceptCall() async {
    await _methodChannel.invokeMethod('acceptCall');
  }

  static Future<void> rejectCall() async {
    await _methodChannel.invokeMethod('rejectCall');
  }

  static Future<void> hangUpCall() async {
    await _methodChannel.invokeMethod('hangUpCall');
  }

  static Future<void> toggleMute(bool muteOn) async {
    await _methodChannel.invokeMethod('toggleMute', {'muteOn': muteOn});
  }

  static Future<void> toggleHold(bool holdOn) async {
    await _methodChannel.invokeMethod('toggleHold', {'holdOn': holdOn});
  }

  static Future<void> toggleSpeaker(bool speakerOn) async {
    await _methodChannel.invokeMethod('toggleSpeaker', {
      'speakerOn': speakerOn,
    });
  }

  // 통화 전환 기능 추가
  static Future<void> switchCalls() async {
    try {
      await _methodChannel.invokeMethod('switchCalls');
      log('[NativeMethods] 통화 전환 요청 성공');
    } catch (e) {
      log('[NativeMethods] 통화 전환 요청 실패: $e');
      rethrow;
    }
  }
  
  // 현재 통화 끊고 수신 통화 받기 기능 추가
  static Future<void> endAndAcceptWaitingCall() async {
    try {
      await _methodChannel.invokeMethod('endAndAcceptWaitingCall');
      log('[NativeMethods] 현재 통화 종료 후 수신 통화 수락 요청 성공');
    } catch (e) {
      log('[NativeMethods] 현재 통화 종료 후 수신 통화 수락 요청 실패: $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> getCurrentCallState() async {
    try {
      final result = await _methodChannel.invokeMapMethod<String, dynamic>(
        'getCurrentCallState',
      );
      if (result == null) {
        log('[NativeMethods] getCurrentCallState 결과 없음, 기본값 반환');
        return {
          'active_state': 'IDLE',
          'active_number': null,
          'holding_state': 'IDLE',
          'holding_number': null,
          'ringing_state': 'IDLE',
          'ringing_number': null
        };
      }

      log('[NativeMethods] getCurrentCallState 결과: $result');
      return result;
    } catch (e) {
      log('[NativeMethods] Error calling getCurrentCallState: $e');
      return {
        'active_state': 'IDLE',
        'active_number': null,
        'holding_state': 'IDLE',
        'holding_number': null,
        'ringing_state': 'IDLE',
        'ringing_number': null
      };
    }
  }

  static Stream<List<Map<String, dynamic>>> getContactsStream({
    int? lastSyncTimestampEpochMillis,
  }) {
    final StreamController<List<Map<String, dynamic>>> controller =
        StreamController<List<Map<String, dynamic>>>();

    _nativeContactsStreamSubscription?.cancel();

    _nativeContactsStreamSubscription = _contactsEventChannel
        .receiveBroadcastStream(lastSyncTimestampEpochMillis)
        .listen(
          (dynamic event) {
            if (controller.isClosed) return;

            if (event is List) {
              List<Map<String, dynamic>> chunk = [];
              for (final dynamic item in event) {
                if (item is Map) {
                  try {
                    final Map<String, dynamic> contactMap = item
                        .map<String, dynamic>(
                          (key, value) => MapEntry(key.toString(), value),
                        );
                    chunk.add(contactMap);
                  } catch (e) {
                    log(
                      '[NativeMethods] getContactsStream: Error converting map item: $item, error: $e',
                    );
                  }
                } else {
                  log(
                    '[NativeMethods] getContactsStream: Received non-Map item in list: $item',
                  );
                }
              }

              if (chunk.isNotEmpty) {
                controller.add(chunk);
              } else {
                controller.add([]);
              }
            } else {
              controller.add([]);
            }
          },
          onError: (dynamic error, StackTrace stackTrace) {
            if (controller.isClosed) return;
            if (error is PlatformException) {
              log(
                '[NativeMethods] getContactsStream: PlatformException: ${error.code} - ${error.message} Details: ${error.details}',
              );
            } else {
              log(
                '[NativeMethods] getContactsStream: Error: $error\nStackTrace: $stackTrace',
              );
            }
            controller.addError(error, stackTrace);
          },
          onDone: () {
            if (controller.isClosed) return;
            log(
              '[NativeMethods] getContactsStream: Native stream subscription done.',
            );
            controller.close();
          },
          cancelOnError: true,
        );

    controller.onCancel = () {
      log(
        '[NativeMethods] getContactsStream: Stream cancelled by listener. Cancelling native subscription.',
      );
      _nativeContactsStreamSubscription?.cancel();
      _nativeContactsStreamSubscription = null;
    };

    return controller.stream;
  }

  static Future<String> upsertContact({
    String? rawContactId,
    required String displayName,
    required String firstName,
    required String middleName,
    required String lastName,
    required String phoneNumber,
    String? memo,
  }) async {
    try {
      final String result = await _methodChannel.invokeMethod('upsertContact', {
        'rawContactId': rawContactId,
        'displayName': displayName,
        'firstName': firstName,
        'middleName': middleName,
        'lastName': lastName,
        'phoneNumber': phoneNumber,
        'memo': memo,
      });
      return result;
    } on PlatformException catch (e) {
      log(
        '[NativeMethods] Error upserting contact: ${e.message} Details: ${e.details}',
      );
      rethrow;
    }
  }

  static Future<bool> deleteContact(String id) async {
    try {
      final bool result = await _methodChannel.invokeMethod('deleteContact', {
        'id': id,
      });
      return result;
    } on PlatformException catch (e) {
      log(
        '[NativeMethods] Error deleting contact: ${e.message} Details: ${e.details}',
      );
      return false;
    }
  }
}
