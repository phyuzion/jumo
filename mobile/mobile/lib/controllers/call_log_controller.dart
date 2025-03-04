// lib/controllers/call_log_controller.dart
import 'package:call_log/call_log.dart';
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
        'number': e.number,
        'name': e.name,
        'callType': e.callType, // or e.callType.name
        'duration': e.duration,
        'timestamp': e.timestamp, // ms
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

    // 6) newList 를 storage에 저장 (실제 '최신 200개'로 갱신)
    await box.write(storageKey, newList);

    // 7) "새로 추가/변경된" 항목 리스트 반환
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
