import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:flutter_sms_intellect/flutter_sms_intellect.dart';
import 'package:hive_ce/hive.dart';
import 'package:mobile/graphql/log_api.dart';
import 'package:mobile/utils/constants.dart';

class SmsController {
  static const storageKey = 'sms_logs';
  Box get _smsLogBox => Hive.box(storageKey);

  /// 최신 SMS 가져와 로컬(Hive) 저장 + 백그라운드 서비스에 업로드 요청
  Future<void> refreshSms() async {
    try {
      // SMS 읽기 (권한 필요)
      final stepWatch = Stopwatch()..start();
      // count 제한 확인 (필요 시 조정)
      final messages = await SmsInbox.getAllSms(count: 30);
      log(
        '[SmsController] SmsInbox.getAllSms() took: ${stepWatch.elapsedMilliseconds}ms, count: ${messages.length}',
      );
      stepWatch.reset();

      stepWatch.start();
      final smsList = <Map<String, dynamic>>[];
      for (final msg in messages) {
        final map = {
          'address': normalizePhone(msg.address ?? ''),
          'body': msg.body ?? '',
          'date': localEpochToUtcEpoch(msg.date ?? 0),
          'type': msg.type ?? '',
        };
        if ((map['address'] as String).isNotEmpty) {
          smsList.add(map);
        }
      }
      log(
        '[SmsController] Processing SMS took: ${stepWatch.elapsedMilliseconds}ms',
      );
      stepWatch.reset();

      // 로컬(Hive) 저장 (JSON 문자열)
      stepWatch.start();
      await _smsLogBox.put('logs', jsonEncode(smsList));
      log(
        '[SmsController] Saving SMS to Hive took: ${stepWatch.elapsedMilliseconds}ms',
      );
      stepWatch.stop();

      // 서버 업로드 요청 (백그라운드)
      final smsForServer = prepareSmsForServer(smsList);
      if (smsForServer.isNotEmpty) {
        await LogApi.updateSMSLog(smsForServer);
      }
    } catch (e, st) {
      log('[SmsController] refreshSms error: $e\n$st');
    }
  }

  /// 서버 전송용 데이터 준비 (static으로 변경)
  static List<Map<String, dynamic>> prepareSmsForServer(
    List<Map<String, dynamic>> localSms,
  ) {
    return localSms.map((m) {
      final phone = m['address'] as String? ?? '';
      final content = m['body'] as String? ?? '';
      final timeStr = (m['date'] ?? 0).toString(); // epoch(int) -> string
      final smsType = (m['type'] ?? '').toString();

      return {
        'phoneNumber': phone,
        'time': timeStr,
        'content': content,
        'smsType': smsType,
      };
    }).toList();
  }

  /// 로컬(Hive)에 저장된 smsLogs 읽기
  List<Map<String, dynamic>> getSavedSms() {
    final logString = _smsLogBox.get('logs', defaultValue: '[]') as String;
    try {
      final decodedList = jsonDecode(logString) as List;
      return decodedList.cast<Map<String, dynamic>>().toList();
    } catch (e) {
      log('[SmsController] Error decoding SMS logs from Hive: $e');
      return [];
    }
  }
}
