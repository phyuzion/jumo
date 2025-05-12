import 'dart:async';
import 'dart:developer';
import 'package:flutter/services.dart';
import 'package:mobile/graphql/log_api.dart';
import 'package:mobile/repositories/sms_log_repository.dart';
import 'package:mobile/utils/constants.dart';
import 'package:flutter/foundation.dart';

class SmsController with ChangeNotifier {
  final SmsLogRepository _smsLogRepository;

  List<Map<String, dynamic>> _smsLogs = [];
  List<Map<String, dynamic>> get smsLogs => _smsLogs;

  static const MethodChannel _methodChannel = MethodChannel(
    'com.jumo.mobile/sms_query',
  );
  static const EventChannel _eventChannel = EventChannel(
    'com.jumo.mobile/sms_events',
  );
  StreamSubscription? _smsEventSubscription;

  SmsController(this._smsLogRepository);

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
      // 1. 로컬 저장소에서 24시간 이내 문자 리스트를 먼저 가져온다.
      final List<Map<String, dynamic>> localList =
          await _smsLogRepository.getAllSmsLogs();
      final Set<String> localKeys =
          localList.map((e) => _generateSmsKey(e)).toSet();

      // 2. 네이티브에서 24시간 이내 문자 리스트를 받아온다.
      final now = DateTime.now();
      final int queryFromTimestamp =
          now.subtract(const Duration(days: 1)).millisecondsSinceEpoch;
      final int queryUntilTimestamp = now.millisecondsSinceEpoch;

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
        log('[SmsController] No SMS found from native for last 24 hours.');
        await _smsLogRepository.clearSmsLogs();
        return;
      }

      List<Map<String, dynamic>> nativeSmsList =
          nativeSmsListDyn.map((item) {
            final map = Map<String, dynamic>.from(item as Map);
            // type이 int면 String으로 변환, String이면 그대로, 아니면 'UNKNOWN'
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
      log(
        '[SmsController] Fetched ${nativeSmsList.length} SMS from native (24시간 이내).',
      );

      // 3. 두 리스트를 비교해서, 로컬에 없는(새로 들어온) 문자만 추출한다.
      final List<Map<String, dynamic>> newSmsList =
          nativeSmsList
              .where((sms) => !localKeys.contains(_generateSmsKey(sms)))
              .toList();

      // 4. 로컬 저장소는 네이티브에서 받아온 전체 리스트로 즉시 덮어쓴다.
      await _smsLogRepository.saveSmsLogs(nativeSmsList);
      _smsLogs = nativeSmsList;
      notifyListeners();
      log(
        '[SmsController] Local SMS log updated with ${nativeSmsList.length} SMS (24시간 이내 전체 덮어쓰기).',
      );

      // 5. 새 문자만 서버에 업로드한다.
      final List<Map<String, dynamic>> smsToUpload =
          newSmsList.where((sms) {
            final typeStr = sms['type'] as String;
            return typeStr == 'INBOX' || typeStr == 'SENT';
          }).toList();

      if (smsToUpload.isNotEmpty) {
        smsToUpload.sort(
          (a, b) => (a['date'] as int).compareTo(b['date'] as int),
        );
        final smsForServer = prepareSmsForServer(smsToUpload);
        if (smsForServer.isNotEmpty) {
          try {
            log(
              '[SmsController] Uploading ${smsForServer.length} new INBOX/SENT SMS to server.',
            );
            bool uploadSuccess = await LogApi.updateSMSLog(smsForServer);
            if (uploadSuccess) {
              log('[SmsController] SMS upload successful.');
            } else {
              log('[SmsController] SMS upload failed (API returned false).');
            }
          } catch (uploadError) {
            log('[SmsController] LogApi.updateSMSLog FAILED: $uploadError');
          }
        }
      } else {
        log('[SmsController] No new INBOX/SENT SMS to upload after filtering.');
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

  // 기존 _generateSmsKey를 SmsController에도 복사(혹은 static으로 이동) 필요
  String _generateSmsKey(Map<String, dynamic> smsMap) {
    final nativeId = smsMap['native_id'];
    final date = smsMap['date'];
    final address = smsMap['address'];
    if (nativeId != null && nativeId != 0) {
      return 'sms_nid_[${nativeId}]';
    }
    if (date != null && address != null) {
      return 'sms_dateaddr_[${date}_${address.hashCode}]';
    }
    return 'sms_fallback_[${DateTime.now().millisecondsSinceEpoch}_${smsMap.hashCode}]';
  }
}
