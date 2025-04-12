// call_log_controller.dart
import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'package:call_e_log/call_log.dart';
import 'package:hive_ce/hive.dart';
import 'package:flutter/foundation.dart';
import 'package:mobile/utils/constants.dart';

class CallLogController with ChangeNotifier {
  static const storageKey = 'call_logs';
  Box get _callLogBox => Hive.box(storageKey);

  List<Map<String, dynamic>> _callLogs = [];
  bool _isLoading = false;

  List<Map<String, dynamic>> get callLogs => _callLogs;
  bool get isLoading => _isLoading;

  CallLogController() {
    loadSavedCallLogs();
  }

  void loadSavedCallLogs() {
    log('[CallLogController] Loading saved call logs from Hive...');
    final logString = _callLogBox.get('logs', defaultValue: '[]') as String;
    try {
      final decodedList = jsonDecode(logString) as List;
      _callLogs = decodedList.cast<Map<String, dynamic>>().toList();
      log('[CallLogController] Loaded ${_callLogs.length} logs from Hive.');
    } catch (e) {
      log('[CallLogController] Error decoding call logs from Hive: $e');
      _callLogs = [];
    }
  }

  /// 통화 목록 새로 읽어서 -> 로컬 DB(Hive)에 저장하고 상태 업데이트
  Future<void> refreshCallLogs() async {
    final stopwatch = Stopwatch()..start();
    log('[CallLogController] Refreshing call logs and saving locally...');

    // <<< 로딩 상태 시작 알림 (마이크로태스크로 지연) >>>
    Future.microtask(() {
      if (!_isLoading) {
        // 중복 방지
        _isLoading = true;
        notifyListeners();
      }
    });
    // _isLoading = true; // <<< 직접 변경 제거
    // notifyListeners(); // <<< 직접 호출 제거

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

      await _callLogBox.put('logs', jsonEncode(newList));
      log(
        '[CallLogController] Saved ${newList.length} call logs locally to Hive.',
      );

      _callLogs = newList;
    } catch (e, st) {
      log('refreshCallLogs error: $e\n$st');
    } finally {
      // <<< 로딩 상태 종료 알림 (마이크로태스크 고려) >>>
      // Future.microtask(() { // 필요 시 microtask 사용
      _isLoading = false;
      notifyListeners();
      // });
      stopwatch.stop();
      log(
        '[CallLogController] Total refreshCallLogs took: ${stopwatch.elapsedMilliseconds}ms',
      );
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
}
