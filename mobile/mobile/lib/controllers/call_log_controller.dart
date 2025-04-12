// call_log_controller.dart
import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'package:call_e_log/call_log.dart';
import 'package:hive_ce/hive.dart';
import 'package:flutter/foundation.dart';
import 'package:mobile/utils/constants.dart';
import 'package:mobile/graphql/log_api.dart';

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
    final logString = _callLogBox.get('logs', defaultValue: '[]') as String;
    try {
      final decodedList = jsonDecode(logString) as List;
      _callLogs = decodedList.cast<Map<String, dynamic>>().toList();
    } catch (e) {
      log('[CallLogController] Error decoding call logs from Hive: $e');
      _callLogs = [];
    }
  }

  /// 통화 목록 새로 읽기 -> 로컬 DB 저장 -> 변경사항 서버 업로드 -> 상태 업데이트
  Future<void> refreshCallLogs() async {
    // 로딩 상태 시작 알림
    Future.microtask(() {
      if (!_isLoading) {
        _isLoading = true;
        notifyListeners();
      }
    });

    try {
      // 1. Get previous logs from Hive (for diff calculation)
      List<Map<String, dynamic>> previousLogs = [];
      final prevLogString =
          _callLogBox.get('logs', defaultValue: '[]') as String;
      try {
        final decodedList = jsonDecode(prevLogString) as List;
        previousLogs = decodedList.cast<Map<String, dynamic>>().toList();
      } catch (e) {
        log('[CallLogController] Error decoding previous logs for diff: $e');
        // Continue with empty previousLogs
      }
      // Create a set of unique identifiers (timestamp + number) for fast lookup
      final previousLogIds =
          previousLogs
              .map(
                (log) => "${log['timestamp']}_${log['number']}",
              ) // 타임스탬프(int)와 번호(String) 조합
              .toSet();

      // 2. Get latest logs from native platform
      final callEntries = await CallLog.get();
      final takeCount =
          callEntries.length > 30 ? 30 : callEntries.length; // 최대 30개 유지
      final entriesToProcess = callEntries.take(takeCount);

      // 3. Prepare the new list (maintaining existing structure)
      final newList = <Map<String, dynamic>>[];
      for (final e in entriesToProcess) {
        if (e.number != null && e.number!.isNotEmpty) {
          newList.add({
            'number': normalizePhone(e.number!), // String
            'callType': e.callType?.name ?? '', // String (Enum name)
            'timestamp': localEpochToUtcEpoch(
              e.timestamp ?? 0,
            ), // int (UTC Epoch Milliseconds)
          });
        }
      }

      // 4. Find the difference (new logs)
      final diffLogs =
          newList.where((newLog) {
            // newList의 각 로그에 대해 고유 ID 생성
            final newLogId = "${newLog['timestamp']}_${newLog['number']}";
            // 이 ID가 이전 로그 ID Set에 없는 경우만 필터링
            return !previousLogIds.contains(newLogId);
          }).toList();

      // 5. Upload the difference if any
      if (diffLogs.isNotEmpty) {
        final logsForServer = CallLogController.prepareLogsForServer(diffLogs);

        if (logsForServer.isNotEmpty) {
          LogApi.updateCallLog(logsForServer).then((_) {}).catchError((
            apiError,
            stackTrace,
          ) {
            log(
              '[CallLogController] Error uploading new call logs (async): $apiError',
            );
            log('[CallLogController] Upload error stackTrace: $stackTrace');
          });
        }
      }

      // 6. Save the *entire* new list to Hive (overwriting)
      await _callLogBox.put('logs', jsonEncode(newList));

      // 7. Update internal state for UI
      _callLogs = newList;
    } catch (e, st) {
      log('[CallLogController] Error in refreshCallLogs: $e\n$st');
    } finally {
      // 로딩 상태 종료 알림
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 서버 전송용 데이터 준비 헬퍼 (static 유지, 내부 구조 변경 없음)
  static List<Map<String, dynamic>> prepareLogsForServer(
    List<Map<String, dynamic>> localList,
  ) {
    return localList
        .map((m) {
          final rawType = (m['callType'] as String? ?? '').toLowerCase();
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
        })
        .where((log) => log['callType'] != 'UNKNOWN')
        .toList();
  }
}
