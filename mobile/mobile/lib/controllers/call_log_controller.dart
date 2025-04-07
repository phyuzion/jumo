// call_log_controller.dart
import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'package:call_e_log/call_log.dart';
import 'package:hive_ce/hive.dart';
import 'package:mobile/utils/app_event_bus.dart';
import 'package:mobile/utils/constants.dart';
import 'package:flutter_background_service/flutter_background_service.dart';

class CallLogController {
  static const storageKey = 'call_logs';
  Box get _callLogBox => Hive.box(storageKey);

  /// 통화 목록 새로 읽어서 -> 로컬 DB(Hive)에 저장 -> 백그라운드 서비스에 업로드 요청
  Future<void> refreshCallLogs() async {
    log('[CallLogController] Refreshing call logs...');
    try {
      final callEntries = await CallLog.get();
      final takeCount = callEntries.length > 30 ? 30 : callEntries.length;
      final entriesToProcess = callEntries.take(takeCount);

      final newList = <Map<String, dynamic>>[];
      for (final e in entriesToProcess) {
        final map = {
          'number': normalizePhone(e.number ?? ''),
          'callType': e.callType?.name ?? '',
          'timestamp': localEpochToUtcEpoch(e.timestamp ?? 0),
        };
        if ((map['number'] as String).isNotEmpty) {
          newList.add(map);
        }
      }

      // (A) 로컬 DB(Hive)에 저장 (덮어쓰기)
      await _callLogBox.clear(); // 기존 내용 삭제
      // Map<String, dynamic> 저장 위해 addAll 대신 put 사용 (키 필요)
      // 또는 List<Map>을 JSON 문자열로 저장?
      // 우선 JSON 문자열로 저장하는 방식 사용
      await _callLogBox.put(
        'logs',
        jsonEncode(newList),
      ); // 'logs' 키에 JSON 문자열 저장
      log(
        '[CallLogController] Saved ${newList.length} call logs locally to Hive.',
      );

      appEventBus.fire(CallLogUpdatedEvent());

      // (B) 백그라운드 서비스에 업로드 요청
      final logsForServer = _prepareLogsForServer(newList);
      if (logsForServer.isNotEmpty) {
        final service = FlutterBackgroundService();
        if (await service.isRunning()) {
          log(
            '[CallLogController] Invoking uploadCallLogs to background service...',
          );
          service.invoke('uploadCallLogs', {'logs': logsForServer});
        } else {
          log(
            '[CallLogController] Background service not running, cannot upload logs now.',
          );
        }
      }
    } catch (e, st) {
      log('refreshCallLogs error: $e\n$st');
    }
  }

  /// 서버 전송용 데이터 준비
  List<Map<String, dynamic>> _prepareLogsForServer(
    List<Map<String, dynamic>> localList,
  ) {
    return localList.map((m) {
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
        'time': (m['timestamp'] ?? 0).toString(),
        'callType': serverType,
      };
    }).toList();
  }

  /// 외부: 로컬(Hive)에 저장된 통화 목록 불러오기
  List<Map<String, dynamic>> getSavedCallLogs() {
    // Hive에서 JSON 문자열 읽어와서 디코딩
    final logString = _callLogBox.get('logs', defaultValue: '[]') as String;
    try {
      final decodedList = jsonDecode(logString) as List;
      return decodedList.cast<Map<String, dynamic>>().toList();
    } catch (e) {
      log('[CallLogController] Error decoding call logs from Hive: $e');
      return [];
    }
  }
}
