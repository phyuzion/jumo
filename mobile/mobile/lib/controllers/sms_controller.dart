// lib/controllers/sms_controller.dart
import 'dart:developer';

import 'package:flutter_sms_intellect/flutter_sms_intellect.dart';
import 'package:get_storage/get_storage.dart';

class SmsController {
  final box = GetStorage();

  static const storageKey = 'smsLogs';

  Future<List<Map<String, dynamic>>> refreshSms() async {
    final messages = await SmsInbox.getAllSms(count: 200);
    final smsList = <Map<String, dynamic>>[];
    for (final msg in messages) {
      // msg: SmsMessage
      final map = {
        'address': msg.address ?? '',
        'body': msg.body ?? '',
        'date': msg.date ?? 0,
        'type': msg.type ?? 0,
      };

      smsList.add(map);
    }

    await box.write(storageKey, smsList);

    return smsList;
  }

  /// 저장된 SMS 목록 읽기
  List<Map<String, dynamic>> getSavedSms() {
    final list = box.read<List>(storageKey) ?? [];
    return list.map((e) => Map<String, dynamic>.from(e)).toList();
  }
}
