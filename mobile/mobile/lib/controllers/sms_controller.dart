// lib/controllers/sms_controller.dart
import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'package:get_storage/get_storage.dart';

class SmsController {
  final SmsQuery _query = SmsQuery();
  final box = GetStorage();

  static const storageKey = 'smsLogs';

  Future<List<Map<String, dynamic>>> refreshSmsWithDiff() async {
    final oldList = getSavedSms(); // List<Map<String,dynamic>>
    final oldSet = _buildSetFromList(oldList);

    final messages = await _query.getAllSms;
    // 정렬이 필요할 수 있음 (기본 오름차순일 가능성)
    // => 내림차순으로 정렬 by date
    messages.sort((a, b) => b.date!.compareTo(a.date!));

    final newTake200 = messages.take(200);
    final newList = <Map<String, dynamic>>[];
    for (final msg in newTake200) {
      // msg: SmsMessage
      final map = {
        'address': msg.address ?? '',
        'body': msg.body ?? '',
        'date': msg.date?.millisecondsSinceEpoch ?? 0,
        // "inbox" or "sent"
        'type': msg.kind,
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
    final id = map['id']?.toString() ?? '';
    final date = map['date']?.toString() ?? '';
    final body = map['body'] ?? '';
    final addr = map['address'] ?? '';
    final tp = map['type']?.toString() ?? '';
    final rd = map['read'].toString(); // read: bool
    return '$id|$date|$body|$addr|$tp|$rd';
  }

  /// list -> set
  Set<String> _buildSetFromList(List<Map<String, dynamic>> list) {
    return list.map((map) => _makeUniqueKey(map)).toSet();
  }
}
