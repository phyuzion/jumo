// lib/controllers/sms_controller.dart
import 'dart:developer';

import 'package:flutter_sms_intellect/flutter_sms_intellect.dart';
import 'package:get_storage/get_storage.dart';

class SmsController {
  final box = GetStorage();

  static const storageKey = 'smsLogs';

  Future<List<Map<String, dynamic>>> refreshSmsWithDiff() async {
    final oldList = getSavedSms(); // List<Map<String,dynamic>>
    final oldSet = _buildSetFromList(oldList);

    final messages = await SmsInbox.getAllSms(count: 200);
    final newList = <Map<String, dynamic>>[];
    for (final msg in messages) {
      // msg: SmsMessage
      final map = {
        'address': msg.address ?? '',
        'body': msg.body ?? '',
        'date': msg.date ?? 0,
        'type': msg.type ?? 0,
      };

      newList.add(map);
    }

    // 3) newSet, oldSet
    final newSet = _buildSetFromList(newList);

    final diffKeys = newSet.difference(oldSet);
    // diffList
    final diffList =
        newList.where((map) {
          final key = _makeUniqueKey(map);
          return diffKeys.contains(key);
        }).toList();

    // 4) 저장
    await box.write(storageKey, newList);

    // 5) 새/변경된 항목 반환
    return diffList;
  }

  /// 저장된 SMS 목록 읽기
  List<Map<String, dynamic>> getSavedSms() {
    final list = box.read<List>(storageKey) ?? [];
    return list.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  /// map -> uniqueKey
  String _makeUniqueKey(Map<String, dynamic> map) {
    // ex: "id_date_body_address_type"
    final date = map['date']?.toString() ?? '';
    final body = map['body'] ?? '';
    final addr = map['address'] ?? '';
    final tp = map['type']?.toString() ?? '';
    return '$date|$body|$addr|$tp';
  }

  /// list -> set
  Set<String> _buildSetFromList(List<Map<String, dynamic>> list) {
    return list.map((map) => _makeUniqueKey(map)).toSet();
  }
}
