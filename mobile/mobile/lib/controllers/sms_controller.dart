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
      final int lastUploadTimestamp =
          await _settingsRepository.getLastSmsSyncTimestamp();
      log('[SmsController] Last SMS sync timestamp: $lastUploadTimestamp');

      List<dynamic>? nativeSmsListDyn;
      try {
        nativeSmsListDyn = await _methodChannel
            .invokeListMethod<Map<dynamic, dynamic>>('getSmsSince', {
              'timestamp': lastUploadTimestamp,
            });
      } on PlatformException catch (e) {
        log("[SmsController] Failed to get SMS from native: '${e.message}'.");
        return;
      }

      if (nativeSmsListDyn == null || nativeSmsListDyn.isEmpty) {
        log(
          '[SmsController] No new SMS found from native since $lastUploadTimestamp.',
        );
        return;
      }

      final List<Map<String, dynamic>> nativeSmsList =
          nativeSmsListDyn
              .map((item) => Map<String, dynamic>.from(item as Map))
              .toList();
      log(
        '[SmsController] Fetched ${nativeSmsList.length} SMS from native (all types since last sync).',
      );

      final List<Map<String, dynamic>> allProcessedSmsForLocalLog = [];
      int latestTimestampInFetchedData = lastUploadTimestamp;

      for (final nativeSms in nativeSmsList) {
        final address = normalizePhone(nativeSms['address'] as String? ?? '');
        final body = nativeSms['body'] as String? ?? '';
        final dateMillis = nativeSms['date'] as int? ?? 0;
        final typeInt = nativeSms['type'] as int? ?? 0;

        String typeStrForLog = mapSmsTypeIntToStringWithAllTypes(typeInt);

        if (address.isNotEmpty && dateMillis > 0) {
          final smsMap = {
            'address': address,
            'body': body,
            'date': dateMillis,
            'type': typeStrForLog,
          };
          allProcessedSmsForLocalLog.add(smsMap);
          if (dateMillis > latestTimestampInFetchedData) {
            latestTimestampInFetchedData = dateMillis;
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
      int latestTimestampInUploadBatch = lastUploadTimestamp;

      for (final nativeSms in nativeSmsList) {
        final address = normalizePhone(nativeSms['address'] as String? ?? '');
        final body = nativeSms['body'] as String? ?? '';
        final dateMillis = nativeSms['date'] as int? ?? 0;
        final typeInt = nativeSms['type'] as int? ?? 0;

        String? typeStrForUpload = mapSmsTypeIntToStringForUpload(typeInt);

        if (typeStrForUpload != null && address.isNotEmpty && dateMillis > 0) {
          final smsMap = {
            'address': address,
            'body': body,
            'date': dateMillis,
            'type': typeStrForUpload,
          };
          smsToUpload.add(smsMap);
          if (dateMillis > latestTimestampInUploadBatch) {
            latestTimestampInUploadBatch = dateMillis;
          }
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
                '[SmsController] SMS upload successful. Updating last sync timestamp to $latestTimestampInUploadBatch',
              );
              await _settingsRepository.setLastSmsSyncTimestamp(
                latestTimestampInUploadBatch,
              );
            } else {
              log('[SmsController] SMS upload failed (API returned false).');
            }
          } catch (uploadError) {
            log('[SmsController] LogApi.updateSMSLog FAILED: $uploadError');
          }
        }
      } else {
        log('[SmsController] No INBOX/SENT SMS to upload.');
        if (latestTimestampInFetchedData > lastUploadTimestamp) {
          // 선택적: INBOX/SENT가 아닌 다른 타입의 새 SMS가 있었던 경우,
          // 다음번 쿼리 범위를 줄이기 위해 타임스탬프 업데이트.
          // log('[SmsController] Updating last sync timestamp to $latestTimestampInFetchedData as new non-uploadable SMS were processed.');
          // await _settingsRepository.setLastSmsSyncTimestamp(latestTimestampInFetchedData);
        }
      }
    } catch (e, st) {
      log('[SmsController] refreshSms error: $e\n$st');
    }
  }

  String? mapSmsTypeIntToStringForUpload(int typeInt) {
    switch (typeInt) {
      case 1:
        return 'INBOX';
      case 2:
        return 'SENT';
      default:
        return null;
    }
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
    List<Map<String, dynamic>> localSms,
  ) {
    return localSms.map((m) {
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
