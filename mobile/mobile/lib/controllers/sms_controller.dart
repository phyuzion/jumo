import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:flutter_sms_intellect/flutter_sms_intellect.dart';
import 'package:hive_ce/hive.dart';
import 'package:mobile/utils/constants.dart';
import 'package:flutter_background_service/flutter_background_service.dart';

class SmsController {
  static const storageKey = 'sms_logs';
  Box get _smsLogBox => Hive.box(storageKey);

  /// 최신 SMS 가져와 로컬(Hive) 저장 + 백그라운드 서비스에 업로드 요청
  Future<void> refreshSms() async {
    log('[SmsController] Refreshing SMS...');
    try {
      // SMS 읽기 (권한 필요)
      final messages = await SmsInbox.getAllSms(count: 10); // 예시: 10개
      final smsList = <Map<String, dynamic>>[];

      for (final msg in messages) {
        final map = {
          'address': normalizePhone(msg.address ?? ''), // 정규화 추가
          'body': msg.body ?? '',
          'date': localEpochToUtcEpoch(msg.date ?? 0),
          'type': msg.type ?? '',
        };
        if ((map['address'] as String).isNotEmpty) {
          smsList.add(map);
        }
      }

      // 로컬(Hive) 저장 (JSON 문자열)
      await _smsLogBox.put('logs', jsonEncode(smsList));
      log('[SmsController] Saved ${smsList.length} SMS logs locally to Hive.');

      // 서버 업로드 요청 (백그라운드)
      final smsForServer = _prepareSmsForServer(smsList);
      if (smsForServer.isNotEmpty) {
        final service = FlutterBackgroundService();
        if (await service.isRunning()) {
          log(
            '[SmsController] Invoking uploadSmsLogs to background service...',
          );
          service.invoke('uploadSmsLogs', {'sms': smsForServer});
        } else {
          log(
            '[SmsController] Background service not running, cannot upload SMS now.',
          );
          // TODO: 서비스 미실행 시 처리 (큐 저장 등)
        }
      }
    } catch (e, st) {
      log('[SmsController] refreshSms error: $e\n$st');
      // TODO: 권한 오류 등 특정 오류 처리
    }
  }

  /// 서버 전송용 데이터 준비
  List<Map<String, dynamic>> _prepareSmsForServer(
    List<Map<String, dynamic>> localSms,
  ) {
    return localSms.map((m) {
      final phone = m['address'] as String? ?? '';
      final content = m['body'] as String? ?? '';
      final timeStr = (m['date'] ?? 0).toString(); // epoch(int) -> string
      final smsType = (m['type'] ?? '').toString(); // TODO: 서버 요구 타입으로 변환?

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
