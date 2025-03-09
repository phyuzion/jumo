import 'dart:developer';

import 'package:call_e_log/call_log.dart';
import 'package:get_storage/get_storage.dart';
import 'package:mobile/utils/app_event_bus.dart';
// 분리된 log_api.dart
import 'package:mobile/graphql/log_api.dart';

class CallLogController {
  final box = GetStorage();
  static const storageKey = 'callLogs';

  /// 디바이스 CallLog (200개)를 읽어 로컬저장 + 서버업로드
  Future<List<Map<String, dynamic>>> refreshCallLogs() async {
    final callEntries = await CallLog.get();
    final take200 = callEntries.take(200);

    final newList = <Map<String, dynamic>>[];
    for (final e in take200) {
      final map = {
        'number': e.number ?? '',
        'name': e.name ?? '',
        'callType': e.callType?.name ?? '', // "incoming"/"outgoing"/"missed"
        'timestamp': e.timestamp ?? 0,
      };
      newList.add(map);
    }

    // 1) 로컬 저장
    await box.write(storageKey, newList);
    appEventBus.fire(CallLogUpdatedEvent());

    // 2) 서버 업로드
    await _uploadToServer(newList);

    return newList;
  }

  /// 내부: 서버에 업로드
  Future<void> _uploadToServer(List<Map<String, dynamic>> localList) async {
    // localList => 서버 규격 변환
    // callType: "incoming" => "IN" / "outgoing" => "OUT" / "missed" => "MISS"
    final logsForServer =
        localList.map((m) {
          final rawType = (m['callType'] as String).toLowerCase();
          String serverType;
          switch (rawType) {
            case 'incoming':
              serverType = 'IN';
              break;
            case 'outgoing':
              serverType = 'OUT';
              break;
            case 'missed':
              serverType = 'MISS';
              break;
            default:
              serverType = 'UNKNOWN';
          }

          return <String, dynamic>{
            'phoneNumber': m['number'] ?? '',
            'time': (m['timestamp'] ?? '').toString(), // epoch → string
            'callType': serverType,
          };
        }).toList();

    try {
      final ok = await LogApi.updateCallLog(logsForServer);
      if (ok) {
        log('통화 로그 업로드 성공');
      }
    } catch (e) {
      log('통화 로그 업로드 실패: $e');
    }
  }

  /// 로컬 저장된 목록 읽기
  List<Map<String, dynamic>> getSavedCallLogs() {
    final list = box.read<List>(storageKey) ?? [];
    return list.map((e) => Map<String, dynamic>.from(e)).toList();
  }
}
