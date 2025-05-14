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
    log(
      '[CallLogController.callLogs_getter] Called. Returning ${_callLogs.length} logs.',
    );
    return _callLogs;
  }

  bool get isLoading {
    log('[CallLogController.isLoading_getter] Called. Returning $_isLoading.');
    return _isLoading;
  }

  // CallLogController(this._callLogRepository, this._settingsRepository) {
  CallLogController(this._callLogRepository) {
    // 생성자에서 SettingsRepository 제거
    log(
      '[CallLogController.constructor] Instance created.',
      // '[CallLogController.constructor] Instance created. Calling loadSavedCallLogs...',
    );
    // loadSavedCallLogs(); // 생성 시 자동 로드 제거
  }

  // 고유 ID 생성 함수 (비교용)
  String _generateCallLogKey(Map<String, dynamic> logEntry) {
    return "${logEntry['timestamp']}_${logEntry['number']}_${logEntry['callType']}_${logEntry['duration']}";
  }

  Future<bool> loadSavedCallLogs() async {
    log('[CallLogController.loadSavedCallLogs] Started.');
    if (_isLoading) {
      log('[CallLogController.loadSavedCallLogs] Already loading, skipping.');
      return false; // 변경 없음
    }
    _isLoading = true;
    // notifyListeners(); // 제거

    List<Map<String, dynamic>> oldLogsSnapshot = List.from(_callLogs);
    bool dataActuallyChanged = false;

    try {
      final loadedLogs = await _callLogRepository.getAllCallLogs();
      log(
        '[CallLogController.loadSavedCallLogs] Loaded ${loadedLogs.length} logs from repository.',
      );

      final Set<String> oldKeys =
          oldLogsSnapshot.map(_generateCallLogKey).toSet();
      final Set<String> newKeys = loadedLogs.map(_generateCallLogKey).toSet();

      if (!setEquals(oldKeys, newKeys)) {
        dataActuallyChanged = true;
      }

      if (dataActuallyChanged) {
        _callLogs = loadedLogs;
        log(
          '[CallLogController.loadSavedCallLogs] _callLogs updated as data changed.',
        );
      } else {
        log(
          '[CallLogController.loadSavedCallLogs] Loaded data is same as current _callLogs.',
        );
      }
    } catch (e) {
      log(
        '[CallLogController.loadSavedCallLogs] Error loading saved call logs: $e',
      );
      dataActuallyChanged = false; // 오류 시 변경 없음으로 간주
    } finally {
      _isLoading = false;
      log(
        '[CallLogController.loadSavedCallLogs] Finished. Returning dataActuallyChanged: $dataActuallyChanged',
      );
      // notifyListeners(); // 제거
    }
    return dataActuallyChanged;
  }

  Future<bool> refreshCallLogs() async {
    log('[CallLogController.refreshCallLogs] Started.');
    if (_isLoading) {
      log('[CallLogController.refreshCallLogs] Already refreshing, skipping.');
      return false; // 변경 없음
    }

    _isLoading = true;
    // notifyListeners(); // 제거

    List<Map<String, dynamic>> oldCallLogsSnapshot = List.from(_callLogs);
    bool dataActuallyChanged = false;

    try {
      List<Map<String, dynamic>> previouslySavedLogsForDiff =
          await _callLogRepository.getAllCallLogs();
      log(
        '[CallLogController.refreshCallLogs] Got ${previouslySavedLogsForDiff.length} previously saved logs for diff.',
      );

      final now = DateTime.now();
      final queryFromTimestamp =
          now.subtract(const Duration(hours: 24)).millisecondsSinceEpoch;
      final queryToTimestamp = now.millisecondsSinceEpoch;

      Iterable<CallLogEntry> callEntries = await CallLog.query(
        dateFrom: queryFromTimestamp,
        dateTo: queryToTimestamp,
      );
      log(
        '[CallLogController.refreshCallLogs] Fetched ${callEntries.length} entries from native.',
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
      log(
        '[CallLogController.refreshCallLogs] Processed ${recentLogs.length} recent logs from native.',
      );

      // 데이터 변경 여부 확인 (Set 기반 비교)
      final Set<String> oldKeys =
          oldCallLogsSnapshot.map(_generateCallLogKey).toSet();
      final Set<String> newKeys = recentLogs.map(_generateCallLogKey).toSet();

      if (!setEquals(oldKeys, newKeys)) {
        dataActuallyChanged = true;
      }

      if (dataActuallyChanged) {
        _callLogs = recentLogs;
        log(
          '[CallLogController.refreshCallLogs] _callLogs updated as data changed.',
        );
      } else {
        log(
          '[CallLogController.refreshCallLogs] Data from native is same as current _callLogs.',
        );
      }

      // 서버 업로드 로직
      final Set<String> previouslySavedLogIdsForDiff =
          previouslySavedLogsForDiff
              .map(_generateCallLogKey)
              .toSet(); // 고유키 생성 함수 사용

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
          LogApi.updateCallLog(logsForServer)
              .then((success) {
                log(
                  '[CallLogController.refreshCallLogs] Async call log upload to server result: $success',
                );
              })
              .catchError((e, s) {
                log(
                  '[CallLogController.refreshCallLogs] Async call log upload error: $e',
                  stackTrace: s,
                );
              });
        }
      }

      await _callLogRepository.saveCallLogs(recentLogs);
      log(
        '[CallLogController.refreshCallLogs] Saved recent logs to repository.',
      );
    } catch (e, st) {
      log('[CallLogController.refreshCallLogs] Error: $e\n$st');
      dataActuallyChanged = false; // 오류 시 변경 없음으로 간주
    } finally {
      _isLoading = false;
      log(
        '[CallLogController.refreshCallLogs] Finished. Returning dataActuallyChanged: $dataActuallyChanged',
      );
      // notifyListeners(); // 제거
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
