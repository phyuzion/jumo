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

  /// 통화 목록 새로 읽어서 -> 로컬 DB(Hive)에 저장하고 이벤트 발생
  /// 서버 업로드는 별도로 요청해야 함.
  Future<void> refreshCallLogs() async {
    final stopwatch = Stopwatch()..start();
    log('[CallLogController] Refreshing call logs and saving locally...');
    List<Map<String, dynamic>> savedList = []; // 저장된 목록 저장용
    try {
      final callEntries = await CallLog.get();
      final takeCount = callEntries.length > 30 ? 30 : callEntries.length;
      final entriesToProcess = callEntries.take(takeCount);
      final newList = <Map<String, dynamic>>[];
      for (final e in entriesToProcess) {
        if (e.number != null && e.number!.isNotEmpty) {
          newList.add({
            'number': normalizePhone(e.number!),
            'callType': e.callType?.name ?? '',
            'timestamp': localEpochToUtcEpoch(e.timestamp ?? 0),
          });
        }
      }

      // Hive 저장
      await _callLogBox.put('logs', jsonEncode(newList));
      savedList = newList; // 저장 성공 시 목록 저장
      log(
        '[CallLogController] Saved ${newList.length} call logs locally to Hive.',
      );

      // UI 갱신 이벤트 발생
      appEventBus.fire(CallLogUpdatedEvent());
      log('[CallLogController] Fired CallLogUpdatedEvent.');
    } catch (e, st) {
      log('refreshCallLogs error: $e\n$st');
    } finally {
      stopwatch.stop();
      log(
        '[CallLogController] Total refreshCallLogs (local save) took: ${stopwatch.elapsedMilliseconds}ms',
      );
    }

    // ***** 서버 업로드 요청 (백그라운드) *****
    if (savedList.isNotEmpty) {
      final service = FlutterBackgroundService();
      // 서비스 실행 여부 확인 후 invoke
      if (await service.isRunning()) {
        log(
          '[CallLogController] Invoking uploadCallLogsNow to background service...',
        );
        service.invoke('uploadCallLogsNow'); // 데이터 전달 없이 요청만 보냄
      } else {
        log(
          '[CallLogController] Background service not running, skipping upload request.',
        );
        // TODO: 서비스 미실행 시 업로드 큐잉 고려
      }
    }
  }

  /// 서버 전송용 데이터 준비 헬퍼 (백그라운드 서비스에서 사용할 수 있도록 public 또는 static으로 변경하거나, 로직 복제)
  /// 여기서는 static 으로 변경
  static List<Map<String, dynamic>> prepareLogsForServer(
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

// CallLogUpdatedEvent 정의 제거 (app_event_bus.dart 사용)
// class CallLogUpdatedEvent {}
