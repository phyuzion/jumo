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
    final stopwatch = Stopwatch()..start(); // 전체 시간 측정 시작
    log('[CallLogController] Refreshing call logs...');
    try {
      final stepWatch = Stopwatch()..start(); // 단계별 시간 측정
      final callEntries = await CallLog.get();
      log(
        '[CallLogController] CallLog.get() took: ${stepWatch.elapsedMilliseconds}ms, count: ${callEntries.length}',
      );
      stepWatch.reset();

      final takeCount = callEntries.length > 30 ? 30 : callEntries.length;
      final entriesToProcess = callEntries.take(takeCount);

      stepWatch.start();
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
      log(
        '[CallLogController] Processing logs took: ${stepWatch.elapsedMilliseconds}ms',
      );
      stepWatch.reset();

      stepWatch.start();
      await _callLogBox.clear();
      await _callLogBox.put('logs', jsonEncode(newList));
      log(
        '[CallLogController] Saving to Hive took: ${stepWatch.elapsedMilliseconds}ms',
      );
      stepWatch.stop();

      appEventBus.fire(CallLogUpdatedEvent());

      final logsForServer = _prepareLogsForServer(newList);
      if (logsForServer.isNotEmpty) {
        final service = FlutterBackgroundService();
        if (await service.isRunning()) {
          log('[CallLogController] Invoking uploadCallLogs...');
          service.invoke('uploadCallLogs', {'logs': logsForServer});
        } else {
          log('[CallLogController] Background service not running for upload.');
        }
      }
    } catch (e, st) {
      log('refreshCallLogs error: $e\n$st');
    } finally {
      stopwatch.stop();
      log(
        '[CallLogController] Total refreshCallLogs took: ${stopwatch.elapsedMilliseconds}ms',
      );
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
