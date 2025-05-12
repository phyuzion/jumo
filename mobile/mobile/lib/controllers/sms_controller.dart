import 'dart:async';
import 'dart:developer';
import 'package:flutter/services.dart';
import 'package:mobile/graphql/log_api.dart';
import 'package:mobile/repositories/settings_repository.dart';
import 'package:mobile/repositories/sms_log_repository.dart';
import 'package:mobile/utils/constants.dart';

class SmsController {
  final SettingsRepository _settingsRepository;
  final SmsLogRepository _smsLogRepository;

  static const MethodChannel _methodChannel = MethodChannel(
    'com.jumo.mobile/sms_query',
  );
  static const EventChannel _eventChannel = EventChannel(
    'com.jumo.mobile/sms_events',
  );
  StreamSubscription? _smsEventSubscription;

  SmsController(this._settingsRepository, this._smsLogRepository);

  Future<void> initializeSmsFeatures() async {
    log('[SmsController] Initializing SMS features...');
    await startSmsObservation();
    listenToSmsEvents();
    await refreshSms();
  }

  Future<void> startSmsObservation() async {
    try {
      await _methodChannel.invokeMethod('startSmsObservation');
      log(
        '[SmsController] Requested to start SMS observation via MethodChannel.',
      );
    } on PlatformException catch (e) {
      log("[SmsController] Failed to start SMS observation: '${e.message}'.");
    }
  }

  void listenToSmsEvents() {
    _smsEventSubscription?.cancel();
    _smsEventSubscription = _eventChannel.receiveBroadcastStream().listen(
      (event) {
        log('[SmsController] Received SMS event from native: $event');
        if (event == "sms_changed_event") {
          log(
            '[SmsController] Triggering refreshSms due to sms_changed_event.',
          );
          refreshSms();
        }
      },
      onError: (error) {
        log('[SmsController] Error in SMS event channel: $error');
      },
      onDone: () {
        log('[SmsController] SMS event channel closed.');
      },
      cancelOnError: true,
    );
    log('[SmsController] Listening to SMS events from native.');
  }

  Future<void> stopSmsObservationAndDispose() async {
    log('[SmsController] Stopping SMS observation and disposing listener...');
    _smsEventSubscription?.cancel();
    _smsEventSubscription = null;
    try {
      await _methodChannel.invokeMethod('stopSmsObservation');
      log(
        '[SmsController] Requested to stop SMS observation via MethodChannel.',
      );
    } on PlatformException catch (e) {
      log("[SmsController] Failed to stop SMS observation: '${e.message}'.");
    }
  }

  Future<void> refreshSms() async {
    log('[SmsController] refreshSms called.');
    try {
      final int lastSyncTimestamp =
          await _settingsRepository.getLastSmsSyncTimestamp();
      log('[SmsController] Last SMS sync timestamp: $lastSyncTimestamp');

      final now = DateTime.now();
      int queryFromTimestamp;
      final int queryUntilTimestamp = now.millisecondsSinceEpoch;

      if (lastSyncTimestamp == 0) {
        queryFromTimestamp =
            now.subtract(const Duration(days: 1)).millisecondsSinceEpoch;
        log(
          '[SmsController] First SMS sync, querying from: $queryFromTimestamp up to $queryUntilTimestamp',
        );
      } else {
        queryFromTimestamp = lastSyncTimestamp + 1;
        log(
          '[SmsController] Subsequent SMS sync, querying from: $queryFromTimestamp up to $queryUntilTimestamp',
        );
      }

      List<dynamic>? nativeSmsListDyn;
      try {
        nativeSmsListDyn = await _methodChannel
            .invokeListMethod<Map<dynamic, dynamic>>('getSmsSince', {
              'timestamp': queryFromTimestamp,
              'toTimestamp': queryUntilTimestamp,
            });
      } on PlatformException catch (e) {
        log("[SmsController] Failed to get SMS from native: '${e.message}'.");
        return;
      }

      if (nativeSmsListDyn == null || nativeSmsListDyn.isEmpty) {
        log(
          '[SmsController] No new SMS found from native for range (from: $queryFromTimestamp, to: $queryUntilTimestamp).',
        );
        if (lastSyncTimestamp == 0) {
          await _settingsRepository.setLastSmsSyncTimestamp(
            queryUntilTimestamp,
          );
          log(
            '[SmsController] Updated lastSmsSyncTimestamp to $queryUntilTimestamp after first sync attempt (no data).',
          );
        }
        return;
      }

      List<Map<String, dynamic>> nativeSmsList =
          nativeSmsListDyn
              .map((item) => Map<String, dynamic>.from(item as Map))
              .toList();
      log(
        '[SmsController] Fetched ${nativeSmsList.length} SMS from native (already time-filtered).',
      );

      final List<Map<String, dynamic>> allProcessedSmsForLocalLog = [];
      int latestTimestampInCurrentBatch = 0;

      for (final nativeSms in nativeSmsList) {
        final address = normalizePhone(nativeSms['address'] as String? ?? '');
        final body = nativeSms['body'] as String? ?? '';
        final dateMillis = nativeSms['date'] as int? ?? 0;
        final typeInt = nativeSms['type'] as int? ?? 0;
        final nativeId = nativeSms['_id'] as int? ?? 0;

        String typeStrForLog = mapSmsTypeIntToStringWithAllTypes(typeInt);

        if (address.isNotEmpty && dateMillis > 0) {
          final smsMap = {
            'native_id': nativeId,
            'address': address,
            'body': body,
            'date': dateMillis,
            'type': typeStrForLog,
          };
          allProcessedSmsForLocalLog.add(smsMap);
          if (dateMillis > latestTimestampInCurrentBatch) {
            latestTimestampInCurrentBatch = dateMillis;
          }
        }
      }

      if (allProcessedSmsForLocalLog.isNotEmpty) {
        await _smsLogRepository.saveSmsLogs(allProcessedSmsForLocalLog);
        log(
          '[SmsController] Saved ${allProcessedSmsForLocalLog.length} processed SMS to local SmsLogRepository.',
        );
      }

      final List<Map<String, dynamic>> smsToUpload = [];

      for (final processedSms in allProcessedSmsForLocalLog) {
        final typeStrForUpload = mapSmsTypeIntToStringForUpload(
          processedSms['type'] as String,
          isAlreadyStringType: true,
        );

        if (typeStrForUpload != null) {
          smsToUpload.add(processedSms);
        }
      }

      if (smsToUpload.isNotEmpty) {
        smsToUpload.sort(
          (a, b) => (a['date'] as int).compareTo(b['date'] as int),
        );

        final smsForServer = prepareSmsForServer(smsToUpload);
        if (smsForServer.isNotEmpty) {
          try {
            log(
              '[SmsController] Uploading ${smsForServer.length} INBOX/SENT SMS to server.',
            );
            bool uploadSuccess = await LogApi.updateSMSLog(smsForServer);
            if (uploadSuccess) {
              log(
                '[SmsController] SMS upload successful. Updating last sync timestamp to $latestTimestampInCurrentBatch',
              );
              await _settingsRepository.setLastSmsSyncTimestamp(
                latestTimestampInCurrentBatch,
              );
            } else {
              log('[SmsController] SMS upload failed (API returned false).');
            }
          } catch (uploadError) {
            log('[SmsController] LogApi.updateSMSLog FAILED: $uploadError');
          }
        }
      } else {
        log('[SmsController] No INBOX/SENT SMS to upload after filtering.');
        if (latestTimestampInCurrentBatch > lastSyncTimestamp &&
            latestTimestampInCurrentBatch != 0) {
          log(
            '[SmsController] Updating last sync timestamp to $latestTimestampInCurrentBatch as new SMS (though not for upload) were processed.',
          );
          await _settingsRepository.setLastSmsSyncTimestamp(
            latestTimestampInCurrentBatch,
          );
        }
      }
    } catch (e, st) {
      log('[SmsController] refreshSms error: $e\n$st');
    }
  }

  String? mapSmsTypeIntToStringForUpload(
    dynamic typeValue, {
    bool isAlreadyStringType = false,
  }) {
    if (isAlreadyStringType && typeValue is String) {
      if (typeValue == 'INBOX' || typeValue == 'SENT') return typeValue;
      return null;
    }
    if (typeValue is int) {
      switch (typeValue) {
        case 1:
          return 'INBOX';
        case 2:
          return 'SENT';
        default:
          return null;
      }
    }
    return null;
  }

  String mapSmsTypeIntToStringWithAllTypes(int typeInt) {
    switch (typeInt) {
      case 1:
        return 'INBOX';
      case 2:
        return 'SENT';
      case 3:
        return 'DRAFT';
      case 4:
        return 'OUTBOX';
      case 5:
        return 'FAILED';
      case 6:
        return 'QUEUED';
      default:
        return 'UNKNOWN_$typeInt';
    }
  }

  List<Map<String, dynamic>> prepareSmsForServer(
    List<Map<String, dynamic>> filteredSmsList,
  ) {
    return filteredSmsList.map((m) {
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
}
