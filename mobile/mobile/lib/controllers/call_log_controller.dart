// call_log_controller.dart
import 'dart:async';
import 'dart:developer';
import 'package:call_e_log/call_log.dart';
import 'package:flutter/foundation.dart';
import 'package:mobile/repositories/call_log_repository.dart';
// SettingsRepository는 이 방식에서는 직접 사용하지 않으므로 주석 처리 또는 삭제 가능
// import 'package:mobile/repositories/settings_repository.dart';
import 'package:mobile/utils/constants.dart';
import 'package:mobile/graphql/log_api.dart';

class CallLogController with ChangeNotifier {
  final CallLogRepository _callLogRepository;
  // final SettingsRepository _settingsRepository; // 더 이상 필요하지 않음

  List<Map<String, dynamic>> _callLogs = [];
  bool _isLoading = false;

  List<Map<String, dynamic>> get callLogs {
    return _callLogs;
  }

  bool get isLoading {
    return _isLoading;
  }

  // CallLogController(this._callLogRepository, this._settingsRepository) {
  CallLogController(this._callLogRepository) {
    // 생성자에서 SettingsRepository 제거
    log('[CallLogController.constructor] Instance created.');
    // loadSavedCallLogs(); // 생성 시 자동 로드 제거
  }

  // 고유 ID 생성 함수 (비교용)
  String _generateCallLogKey(Map<String, dynamic> logEntry) {
    return "${logEntry['timestamp']}_${logEntry['number']}_${logEntry['callType']}_${logEntry['duration']}";
  }

  Future<bool> loadSavedCallLogs() async {
    if (_isLoading) {
      return false;
    }
    _isLoading = true;

    List<Map<String, dynamic>> oldLogsSnapshot = List.from(_callLogs);
    bool dataActuallyChanged = false;

    try {
      final loadedLogs = await _callLogRepository.getAllCallLogs();

      final Set<String> oldKeys =
          oldLogsSnapshot.map(_generateCallLogKey).toSet();
      final Set<String> newKeys = loadedLogs.map(_generateCallLogKey).toSet();

      if (!setEquals(oldKeys, newKeys)) {
        dataActuallyChanged = true;
      }

      if (dataActuallyChanged) {
        _callLogs = loadedLogs;
      }
    } catch (e, st) {
      log(
        '[CallLogController.loadSavedCallLogs] Error loading saved call logs: $e',
        stackTrace: st,
      );
      dataActuallyChanged = false;
    } finally {
      _isLoading = false;
    }
    return dataActuallyChanged;
  }

  Future<bool> refreshCallLogs() async {
    if (_isLoading) {
      return false;
    }

    _isLoading = true;

    List<Map<String, dynamic>> oldCallLogsSnapshot = List.from(_callLogs);
    bool dataActuallyChanged = false;

    try {
      List<Map<String, dynamic>> previouslySavedLogsForDiff =
          await _callLogRepository.getAllCallLogs();

      final now = DateTime.now();
      final queryFromTimestamp =
          now.subtract(const Duration(hours: 24)).millisecondsSinceEpoch;
      final queryToTimestamp = now.millisecondsSinceEpoch;

      Iterable<CallLogEntry> callEntries = await CallLog.query(
        dateFrom: queryFromTimestamp,
        dateTo: queryToTimestamp,
      );

      final List<Map<String, dynamic>> recentLogs = [];
      for (final e in callEntries) {
        if (e.number != null && e.number!.isNotEmpty && e.timestamp != null) {
          recentLogs.add({
            'number': normalizePhone(e.number!),
            'callType': e.callType?.name ?? 'UNKNOWN',
            'timestamp': localEpochToUtcEpoch(e.timestamp!),
            'duration': e.duration ?? 0,
            'name': e.name ?? '',
          });
        }
      }
      recentLogs.sort(
        (a, b) => (b['timestamp'] as int).compareTo(a['timestamp'] as int),
      );

      final Set<String> oldKeys =
          oldCallLogsSnapshot.map(_generateCallLogKey).toSet();
      final Set<String> newKeys = recentLogs.map(_generateCallLogKey).toSet();

      if (!setEquals(oldKeys, newKeys)) {
        dataActuallyChanged = true;
      }

      if (dataActuallyChanged) {
        _callLogs = recentLogs;
      }

      final Set<String> previouslySavedLogIdsForDiff =
          previouslySavedLogsForDiff.map(_generateCallLogKey).toSet();
      final List<Map<String, dynamic>> newLogsToUpload =
          recentLogs.where((logEntry) {
            return !previouslySavedLogIdsForDiff.contains(
              _generateCallLogKey(logEntry),
            );
          }).toList();

      if (newLogsToUpload.isNotEmpty) {
        final logsForServer = CallLogController.prepareLogsForServer(
          newLogsToUpload,
        );
        if (logsForServer.isNotEmpty) {
          LogApi.updateCallLog(logsForServer).then((success) {}).catchError((
            e,
            s,
          ) {
            log(
              '[CallLogController.refreshCallLogs] Async call log upload error: $e',
              stackTrace: s,
            );
          });
        }
      }

      await _callLogRepository.saveCallLogs(recentLogs);
    } catch (e, st) {
      log('[CallLogController.refreshCallLogs] Error: $e', stackTrace: st);
      dataActuallyChanged = false;
    } finally {
      _isLoading = false;
    }
    return dataActuallyChanged;
  }

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
            case 'rejected':
              serverType = 'REJECTED';
              break;
            case 'blocked':
              serverType = 'BLOCKED';
              break;
            case 'answered_externally':
              serverType = 'ANSWERED_EXTERNALLY';
              break;
            default:
              serverType = 'UNKNOWN (${m['callType']})';
          }
          return <String, dynamic>{
            'phoneNumber': m['number'] ?? '',
            'time': (m['timestamp'] ?? 0).toString(),
            'callType': serverType,
          };
        })
        .where((logEntry) => !logEntry['callType'].startsWith('UNKNOWN'))
        .toList();
  }
}
