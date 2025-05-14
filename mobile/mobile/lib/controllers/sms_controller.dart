import 'dart:async';
import 'dart:developer';
import 'package:flutter/services.dart';
import 'package:mobile/graphql/log_api.dart';
import 'package:mobile/repositories/sms_log_repository.dart';
import 'package:mobile/utils/constants.dart';
import 'package:flutter/foundation.dart';
import 'package:mobile/controllers/app_controller.dart';

class SmsController with ChangeNotifier {
  final SmsLogRepository _smsLogRepository;
  final AppController appController;

  List<Map<String, dynamic>> _smsLogs = [];
  List<Map<String, dynamic>> get smsLogs {
    log(
      '[SmsController.smsLogs_getter] Called. Returning ${_smsLogs.length} logs.',
    );
    return _smsLogs;
  }

  static const MethodChannel _methodChannel = MethodChannel(
    'com.jumo.mobile/sms_query',
  );
  static const EventChannel _eventChannel = EventChannel(
    'com.jumo.mobile/sms_events',
  );
  StreamSubscription? _smsEventSubscription;

  SmsController(this._smsLogRepository, this.appController) {
    log('[SmsController.constructor] Instance created.');
  }

  Future<void> initializeSmsFeatures() async {
    log('[SmsController.initializeSmsFeatures] Started.');
    await startSmsObservation();
    listenToSmsEvents();
    log(
      '[SmsController.initializeSmsFeatures] Finished (observation and listener setup).',
    );
  }

  Future<void> startSmsObservation() async {
    log('[SmsController.startSmsObservation] Started.');
    try {
      await _methodChannel.invokeMethod('startSmsObservation');
      log(
        '[SmsController.startSmsObservation] Requested to start SMS observation via MethodChannel.',
      );
    } on PlatformException catch (e) {
      log(
        "[SmsController.startSmsObservation] Failed to start SMS observation: '${e.message}'.",
      );
    }
    log('[SmsController.startSmsObservation] Finished.');
  }

  void listenToSmsEvents() {
    log('[SmsController.listenToSmsEvents] Started.');
    _smsEventSubscription?.cancel();
    _smsEventSubscription = _eventChannel.receiveBroadcastStream().listen(
      (event) {
        log(
          '[SmsController.listenToSmsEvents] Received SMS event from native: $event',
        );
        if (event == "sms_changed_event") {
          log(
            '[SmsController.listenToSmsEvents] Triggering refreshSms due to sms_changed_event.',
          );
          refreshSms().then((changed) {
            if (changed) {
              log(
                '[SmsController.listenToSmsEvents] SMS data changed by event, requesting UI update via AppController.',
              );
              appController.requestUiUpdate(source: 'SmsEvent');
            }
          });
        }
      },
      onError: (error) {
        log(
          '[SmsController.listenToSmsEvents] Error in SMS event channel: $error',
        );
      },
      onDone: () {
        log('[SmsController.listenToSmsEvents] SMS event channel closed.');
      },
      cancelOnError: true,
    );
    log(
      '[SmsController.listenToSmsEvents] Listening to SMS events from native. Finished.',
    );
  }

  Future<void> stopSmsObservationAndDispose() async {
    log('[SmsController.stopSmsObservationAndDispose] Started.');
    _smsEventSubscription?.cancel();
    _smsEventSubscription = null;
    try {
      await _methodChannel.invokeMethod('stopSmsObservation');
      log(
        '[SmsController.stopSmsObservationAndDispose] Requested to stop SMS observation via MethodChannel.',
      );
    } on PlatformException catch (e) {
      log(
        "[SmsController.stopSmsObservationAndDispose] Failed to stop SMS observation: '${e.message}'.",
      );
    }
    log('[SmsController.stopSmsObservationAndDispose] Finished.');
  }

  Future<bool> refreshSms() async {
    log('[SmsController.refreshSms] Started.');
    List<Map<String, dynamic>> oldSmsLogsSnapshot = List.from(_smsLogs);
    bool dataActuallyChanged = false;

    try {
      log(
        '[SmsController.refreshSms] Getting local SMS logs from repository (for diffing new)...',
      );
      final List<Map<String, dynamic>> localStoredSmsForDiff =
          await _smsLogRepository.getAllSmsLogs();
      final Set<String> localStoredKeysForDiff =
          localStoredSmsForDiff.map((e) => _generateSmsKey(e)).toSet();
      log(
        '[SmsController.refreshSms] Got ${localStoredSmsForDiff.length} local SMS logs for diffing new uploads, ${localStoredKeysForDiff.length} unique keys.',
      );

      final now = DateTime.now();
      final int queryFromTimestamp =
          now.subtract(const Duration(days: 1)).millisecondsSinceEpoch;
      final int queryUntilTimestamp = now.millisecondsSinceEpoch;

      log(
        '[SmsController.refreshSms] Querying native SMS from $queryFromTimestamp to $queryUntilTimestamp...',
      );
      List<dynamic>? nativeSmsListDyn;
      try {
        nativeSmsListDyn = await _methodChannel
            .invokeListMethod<Map<dynamic, dynamic>>('getSmsSince', {
              'timestamp': queryFromTimestamp,
              'toTimestamp': queryUntilTimestamp,
            });
      } on PlatformException catch (e) {
        log(
          "[SmsController.refreshSms] Failed to get SMS from native: '${e.message}'.",
        );
        dataActuallyChanged = false;
        return dataActuallyChanged;
      }

      List<Map<String, dynamic>> nativeSmsList = [];
      if (nativeSmsListDyn != null && nativeSmsListDyn.isNotEmpty) {
        nativeSmsList =
            nativeSmsListDyn.map((item) {
              final map = Map<String, dynamic>.from(item as Map);
              final typeRaw = map['type'];
              String typeStr;
              if (typeRaw is int) {
                typeStr = mapSmsTypeIntToStringWithAllTypes(typeRaw);
              } else if (typeRaw is String) {
                typeStr = typeRaw;
              } else {
                typeStr = 'UNKNOWN';
              }
              map['type'] = typeStr;
              return map;
            }).toList();
      }
      log(
        '[SmsController.refreshSms] Fetched and processed ${nativeSmsList.length} SMS from native (24시간 이내).',
      );

      if (oldSmsLogsSnapshot.length != nativeSmsList.length) {
        dataActuallyChanged = true;
      } else {
        for (int i = 0; i < oldSmsLogsSnapshot.length; i++) {
          if (!mapEquals(oldSmsLogsSnapshot[i], nativeSmsList[i])) {
            dataActuallyChanged = true;
            break;
          }
        }
      }

      if (dataActuallyChanged) {
        _smsLogs = nativeSmsList;
        log(
          '[SmsController.refreshSms] _smsLogs updated as data changed (${_smsLogs.length} items).',
        );
      } else {
        log(
          '[SmsController.refreshSms] Loaded data from native is same as current _smsLogs.',
        );
      }

      await _smsLogRepository.saveSmsLogs(nativeSmsList);
      log(
        '[SmsController.refreshSms] Local SMS storage updated with ${nativeSmsList.length} SMS (full overwrite of last 24h).',
      );

      final List<Map<String, dynamic>> newSmsToUploadToServer =
          nativeSmsList
              .where(
                (sms) => !localStoredKeysForDiff.contains(_generateSmsKey(sms)),
              )
              .toList();
      log(
        '[SmsController.refreshSms] Found ${newSmsToUploadToServer.length} new SMS messages for server upload.',
      );

      final List<Map<String, dynamic>> smsToUploadFilteredType =
          newSmsToUploadToServer.where((sms) {
            final typeStr = sms['type'] as String;
            return typeStr == 'INBOX' || typeStr == 'SENT';
          }).toList();

      if (smsToUploadFilteredType.isNotEmpty) {
        smsToUploadFilteredType.sort(
          (a, b) => (a['date'] as int).compareTo(b['date'] as int),
        );
        final smsForServer = prepareSmsForServer(smsToUploadFilteredType);
        log(
          '[SmsController.refreshSms] Prepared ${smsForServer.length} INBOX/SENT SMS for server upload.',
        );
        if (smsForServer.isNotEmpty) {
          try {
            log(
              '[SmsController.refreshSms] Uploading ${smsForServer.length} SMS to server...',
            );
            LogApi.updateSMSLog(smsForServer)
                .then((uploadSuccess) {
                  if (uploadSuccess) {
                    log(
                      '[SmsController.refreshSms] SMS upload successful (async).',
                    );
                  } else {
                    log(
                      '[SmsController.refreshSms] SMS upload failed (API returned false) (async).',
                    );
                  }
                })
                .catchError((uploadError) {
                  log(
                    '[SmsController.refreshSms] LogApi.updateSMSLog FAILED (async): $uploadError',
                  );
                });
          } catch (e) {
            log(
              '[SmsController.refreshSms] Synchronous error during LogApi.updateSMSLog call (should be rare): $e',
            );
          }
        }
      } else {
        log(
          '[SmsController.refreshSms] No new INBOX/SENT SMS to upload after filtering.',
        );
      }
    } catch (e, st) {
      log('[SmsController.refreshSms] Error: $e\n$st');
      dataActuallyChanged = false;
    } finally {
      log(
        '[SmsController.refreshSms] Finished. Returning dataActuallyChanged: $dataActuallyChanged',
      );
    }
    return dataActuallyChanged;
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

  String _generateSmsKey(Map<String, dynamic> smsMap) {
    final nativeId = smsMap['native_id'];
    final date = smsMap['date'];
    final address = smsMap['address'];
    if (nativeId != null && nativeId != 0) {
      return 'sms_nid_ [$nativeId]';
    }
    if (date != null && address != null) {
      return 'sms_dateaddr_ [${date}_${address.hashCode}]';
    }
    return 'sms_fallback_ [${DateTime.now().millisecondsSinceEpoch}_${smsMap.hashCode}]';
  }
}
