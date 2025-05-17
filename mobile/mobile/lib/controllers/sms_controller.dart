import 'dart:async';
import 'dart:developer';
import 'package:flutter/services.dart';
import 'package:mobile/graphql/log_api.dart';
import 'package:mobile/repositories/sms_log_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:mobile/controllers/app_controller.dart';

class SmsController with ChangeNotifier {
  final SmsLogRepository _smsLogRepository;
  final AppController appController;

  List<Map<String, dynamic>> _smsLogs = [];
  List<Map<String, dynamic>> get smsLogs => _smsLogs;

  static const MethodChannel _methodChannel = MethodChannel(
    'com.jumo.mobile/sms_query',
  );
  static const EventChannel _eventChannel = EventChannel(
    'com.jumo.mobile/sms_events',
  );
  StreamSubscription? _smsEventSubscription;

  bool _isSyncing = false;
  static const Duration _messageLookbackPeriod = Duration(days: 1);

  SmsController(this._smsLogRepository, this.appController) {
    log('[SmsController.constructor] Instance created.');
  }

  Future<void> initializeSmsFeatures() async {
    try {
      await startSmsObservation();
      listenToSmsEvents();
      syncMessages();
    } catch (e, s) {
      log('[SmsController.initializeSmsFeatures] Error: $e', stackTrace: s);
    }
  }

  Future<void> startSmsObservation() async {
    try {
      await _methodChannel.invokeMethod('startSmsObservation');
      log('[SmsController.startSmsObservation] SMS observation started.');
    } on PlatformException catch (e) {
      log(
        "[SmsController.startSmsObservation] Failed to start SMS observation: '${e.message}'.",
      );
    }
  }

  void listenToSmsEvents() {
    // 기존 구독이 이미 있는 경우 새로 구독하지 않음
    if (_smsEventSubscription != null) {
      log('[SmsController.listenToSmsEvents] 기존 이벤트 구독이 있음. 메시지 동기화만 시작.');
      syncMessages();
      return;
    }

    _smsEventSubscription = _eventChannel.receiveBroadcastStream().listen(
      (event) {
        if (event == "message_changed_event" || event == "sms_changed_event") {
          log(
            '[SmsController.listenToSmsEvents] Message change event received.',
          );
          syncMessages();
        }
      },
      onError: (error) {
        log(
          '[SmsController.listenToSmsEvents] Error in SMS event channel: $error',
        );
      },
      onDone: () {
        log('[SmsController.listenToSmsEvents] Event channel closed.');
        // 이벤트 채널이 닫히면 구독 참조 제거 (다시 구독할 수 있도록)
        _smsEventSubscription = null;
      },
      cancelOnError: false,
    );

    // 구독이 새로 시작될 때 자동으로 메시지 동기화 시작
    log('[SmsController.listenToSmsEvents] 이벤트 채널 구독 시작됨. 메시지 동기화 시작.');
    syncMessages();
  }

  Future<void> stopSmsObservationAndDispose() async {
    await _smsEventSubscription?.cancel();
    _smsEventSubscription = null;

    try {
      await _methodChannel.invokeMethod('stopSmsObservation');
      log(
        '[SmsController.stopSmsObservationAndDispose] SMS observation stopped.',
      );
    } on PlatformException catch (e) {
      log(
        "[SmsController.stopSmsObservationAndDispose] Failed to stop SMS observation: '${e.message}'.",
      );
    }
  }

  void refreshSms() {
    syncMessages();
  }

  void syncMessages() {
    if (_isSyncing) {
      log('[SmsController.syncMessages] Sync already in progress, skipping.');
      return;
    }

    _isSyncing = true;

    _processSyncMessagesAsync();
  }

  Future<void> _processSyncMessagesAsync() async {
    bool dataChanged = false;

    try {
      final List<Map<String, dynamic>> currentStoredLogs =
          await _smsLogRepository.getAllSmsLogs();

      log(
        '[SmsController.syncMessages] 로컬 저장소에서 ${currentStoredLogs.length}개 메시지 로드됨',
      );

      final Map<String, Map<String, dynamic>> existingMsgMap = {
        for (var msg in currentStoredLogs) _generateSmsKey(msg): msg,
      };

      final DateTime now = DateTime.now();
      final DateTime oneDayAgo = now.subtract(_messageLookbackPeriod);

      final List<Map<String, dynamic>> newMessages =
          await _fetchMessagesFromNative(oneDayAgo);

      final Map<String, Map<String, dynamic>> mergedMessages = {};

      for (final msg in currentStoredLogs) {
        final int msgDate = msg['date'] as int? ?? 0;
        final DateTime msgDateTime = DateTime.fromMillisecondsSinceEpoch(
          msgDate,
        );

        if (msgDateTime.isAfter(oneDayAgo)) {
          final String key = _generateSmsKey(msg);
          mergedMessages[key] = msg;
        }
      }

      List<Map<String, dynamic>> newMsgsToUploadToServer = [];
      for (final msg in newMessages) {
        final String key = _generateSmsKey(msg);

        if (!existingMsgMap.containsKey(key)) {
          newMsgsToUploadToServer.add(msg);
        }

        mergedMessages[key] = msg;
      }

      final List<Map<String, dynamic>> mergedMessagesList =
          mergedMessages.values.toList();

      mergedMessagesList.sort(
        (a, b) => (b['date'] as int? ?? 0).compareTo(a['date'] as int? ?? 0),
      );

      if (mergedMessagesList.length != _smsLogs.length ||
          !_areListsEqual(_smsLogs, mergedMessagesList)) {
        _smsLogs = mergedMessagesList;
        dataChanged = true;

        await _smsLogRepository.saveSmsLogs(mergedMessagesList);
        log(
          '[SmsController.syncMessages] ${mergedMessagesList.length}개 메시지를 로컬 저장소에 저장',
        );

        if (newMsgsToUploadToServer.isNotEmpty) {
          final List<Map<String, dynamic>> msgsToUploadFilteredType =
              newMsgsToUploadToServer.where((sms) {
                final typeStr = sms['type'] as String;
                return typeStr == 'INBOX' || typeStr == 'SENT';
              }).toList();

          if (msgsToUploadFilteredType.isNotEmpty) {
            msgsToUploadFilteredType.sort(
              (a, b) => (a['date'] as int).compareTo(b['date'] as int),
            );

            await _uploadMessagesToServer(msgsToUploadFilteredType);
            log(
              '[SmsController.syncMessages] ${msgsToUploadFilteredType.length}개 새 메시지를 서버에 업로드',
            );
          }
        }

        appController.requestUiUpdate(source: 'SmsEvent');
      } else {
        log(
          '[SmsController.syncMessages] 메시지 변경 없음. 현재 ${_smsLogs.length}개 메시지 유지',
        );
      }
    } catch (e, st) {
      log('[SmsController.syncMessages] Error: $e', stackTrace: st);
    } finally {
      _isSyncing = false;
    }
  }

  bool _areListsEqual(
    List<Map<String, dynamic>> list1,
    List<Map<String, dynamic>> list2,
  ) {
    if (list1.length != list2.length) return false;

    for (int i = 0; i < list1.length; i++) {
      if (!mapEquals(list1[i], list2[i])) {
        return false;
      }
    }

    return true;
  }

  Future<List<Map<String, dynamic>>> _fetchMessagesFromNative(
    DateTime since,
  ) async {
    try {
      final int queryFromTimestamp = since.millisecondsSinceEpoch;
      final int queryUntilTimestamp = DateTime.now().millisecondsSinceEpoch;

      log(
        '[SmsController._fetchMessagesFromNative] 메시지 조회: ${DateTime.fromMillisecondsSinceEpoch(queryFromTimestamp)} ~ ${DateTime.fromMillisecondsSinceEpoch(queryUntilTimestamp)}',
      );

      List<dynamic>? nativeMsgListDyn;
      try {
        nativeMsgListDyn = await _methodChannel
            .invokeListMethod<Map<dynamic, dynamic>>('getMessagesSince', {
              'timestamp': queryFromTimestamp,
              'toTimestamp': queryUntilTimestamp,
            });
      } catch (e) {
        log(
          '[SmsController._fetchMessagesFromNative] Fallback to getSmsSince (SMS only): $e',
        );
        nativeMsgListDyn = await _methodChannel
            .invokeListMethod<Map<dynamic, dynamic>>('getSmsSince', {
              'timestamp': queryFromTimestamp,
              'toTimestamp': queryUntilTimestamp,
            });
      }

      if (nativeMsgListDyn != null && nativeMsgListDyn.isNotEmpty) {
        final result =
            nativeMsgListDyn.map((item) {
              return Map<String, dynamic>.from(item as Map);
            }).toList();

        log(
          '[SmsController._fetchMessagesFromNative] ${result.length}개 메시지를 네이티브에서 가져옴',
        );
        return result;
      }

      log('[SmsController._fetchMessagesFromNative] 네이티브에서 가져온 메시지 없음');
      return [];
    } on PlatformException catch (e) {
      log(
        "[SmsController._fetchMessagesFromNative] Failed to get messages: '${e.message}'.",
      );
      return [];
    }
  }

  Future<bool> _uploadMessagesToServer(
    List<Map<String, dynamic>> messages,
  ) async {
    if (messages.isEmpty) return true;

    try {
      final msgsForServer = prepareMessagesForServer(messages);
      if (msgsForServer.isNotEmpty) {
        final success = await LogApi.updateSMSLog(msgsForServer);
        return success;
      }
      return true;
    } catch (e, s) {
      log(
        '[SmsController._uploadMessagesToServer] Upload error: $e',
        stackTrace: s,
      );
      return false;
    }
  }

  List<Map<String, dynamic>> prepareMessagesForServer(
    List<Map<String, dynamic>> filteredMsgList,
  ) {
    return filteredMsgList.map((m) {
      final phone = m['address'] as String? ?? '';
      final content = m['body'] as String? ?? '';
      final timeStr = (m['date'] ?? 0).toString();
      final smsType = m['type'] as String;

      return {
        'phoneNumber': phone,
        'time': timeStr,
        'content': content,
        'smsType': smsType,
      };
    }).toList();
  }

  String _generateSmsKey(Map<String, dynamic> smsMap) {
    final date = smsMap['date'];
    final address = smsMap['address'];

    if (date != null && address != null) {
      return "msg_key_[${date}_${address.hashCode}]";
    }
    return "msg_fallback_[${DateTime.now().millisecondsSinceEpoch}_${smsMap.hashCode}]";
  }
}
