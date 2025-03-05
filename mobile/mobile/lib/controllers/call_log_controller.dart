// lib/controllers/call_log_controller.dart
import 'dart:developer';

import 'package:call_e_log/call_log.dart';
import 'package:get_storage/get_storage.dart';

class CallLogController {
  final box = GetStorage();

  /// key for storage
  static const storageKey = 'callLogs';

  /// 최근 200개 통화내역 가져와서 get_storage 에 저장하되,
  /// 이전 목록과 비교 -> "새로운/변경된" 항목을 return
  Future<List<Map<String, dynamic>>> refreshCallLogsWithDiff() async {
    // 1) 이전 목록 읽기
    final oldList = getSavedCallLogs(); // List<Map<String,dynamic>>
    final oldSet = _buildSetFromList(oldList); // Set<String> of unique keys

    // 2) 새 목록 호출
    final newEntries =
        await CallLog.get(); // Iterable<CallLogEntry> (newest first)
    final newTake200 = newEntries.take(200);

    final newList = <Map<String, dynamic>>[];
    for (final e in newTake200) {
      final map = {
        'number': e.number ?? '',
        'name': e.name ?? '',
        // e.callType.name -> "incoming"/"outgoing"/"missed" etc. (string)
        'callType': e.callType?.name ?? '',
        'duration': e.duration ?? 0,
        'timestamp': e.timestamp ?? 0,
      };
      newList.add(map);
    }

    // 3) 새 목록 -> set
    final newSet = _buildSetFromList(newList);

    // 4) 새 항목(혹은 변경된 항목): newSet - oldSet
    //    => uniqueKey가 old엔 없고 new엔 있는
    final diffKeys = newSet.difference(oldSet);

    // 5) diffKeys 에 해당하는 실제 map 을 추출
    final diffList =
        newList.where((map) {
          final key = _makeUniqueKey(map);
          return diffKeys.contains(key);
        }).toList();

    await box.write(storageKey, newList);

    return diffList;
  }

  /// get_storage 에서 이전 목록 읽기
  List<Map<String, dynamic>> getSavedCallLogs() {
    final list = box.read<List>(storageKey) ?? [];
    return list.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  /// 내부: Map -> uniqueKey
  String _makeUniqueKey(Map<String, dynamic> map) {
    // e.g. "timestamp_callType_number_duration"
    // number could be null => handle
    final ts = map['timestamp']?.toString() ?? '';
    final ct = map['callType']?.toString() ?? '';
    final num = map['number'] ?? 'unknown';
    final dur = map['duration']?.toString() ?? '';
    return '$ts|$ct|$num|$dur';
  }

  /// 내부: List<Map> -> Set<String> (uniqueKey)
  Set<String> _buildSetFromList(List<Map<String, dynamic>> list) {
    final set = <String>{};
    for (final map in list) {
      final key = _makeUniqueKey(map);
      set.add(key);
    }
    return set;
  }
}
