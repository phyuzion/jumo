// call_log_controller.dart
import 'dart:async';
import 'dart:developer';
import 'package:call_e_log/call_log.dart';
import 'package:flutter/foundation.dart';
import 'package:mobile/repositories/call_log_repository.dart';
import 'package:mobile/repositories/settings_repository.dart';
import 'package:mobile/utils/constants.dart';
import 'package:mobile/graphql/log_api.dart';

class CallLogController with ChangeNotifier {
  final CallLogRepository _callLogRepository;
  final SettingsRepository _settingsRepository;

  List<Map<String, dynamic>> _callLogs = [];
  bool _isLoading = false;

  List<Map<String, dynamic>> get callLogs => _callLogs;
  bool get isLoading => _isLoading;

  CallLogController(this._callLogRepository, this._settingsRepository) {
    loadSavedCallLogs();
  }

  Future<void> loadSavedCallLogs() async {
    if (_isLoading) return;
    _isLoading = true;
    notifyListeners();
    try {
      _callLogs = await _callLogRepository.getAllCallLogs();
      log(
        '[CallLogController] Loaded ${_callLogs.length} saved call logs from repository.',
      );
    } catch (e) {
      log('[CallLogController] Error loading saved call logs: $e');
      _callLogs = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 통화 목록 새로 읽기 -> 로컬 DB 저장 -> 변경사항 서버 업로드 -> 상태 업데이트
  Future<void> refreshCallLogs() async {
    if (_isLoading) {
      log('[CallLogController] Already refreshing call logs, skipping.');
      return;
    }
    log('[CallLogController] refreshCallLogs called.');
    _isLoading = true;
    notifyListeners();

    try {
      final int lastSyncTimestamp =
          await _settingsRepository.getLastCallLogSyncTimestamp();
      log(
        '[CallLogController] Last CallLog sync timestamp: $lastSyncTimestamp',
      );

      Iterable<CallLogEntry> callEntries;
      final now = DateTime.now();
      int queryFromTimestamp;
      int queryToTimestamp = now.millisecondsSinceEpoch;

      if (lastSyncTimestamp == 0) {
        queryFromTimestamp =
            now.subtract(const Duration(days: 1)).millisecondsSinceEpoch;
        log(
          '[CallLogController] First sync or no timestamp, querying logs from: $queryFromTimestamp to $queryToTimestamp',
        );
        callEntries = await CallLog.query(
          dateFrom: queryFromTimestamp,
          dateTo: queryToTimestamp,
        );
      } else {
        queryFromTimestamp = lastSyncTimestamp + 1;
        log(
          '[CallLogController] Querying logs from: $queryFromTimestamp to $queryToTimestamp',
        );
        callEntries = await CallLog.query(
          dateFrom: queryFromTimestamp,
          dateTo: queryToTimestamp,
        );
      }
      log(
        '[CallLogController] CallLog.query returned ${callEntries.length} entries.',
      );

      final List<Map<String, dynamic>> newFetchedLogs = [];
      int latestTimestampInBatch = lastSyncTimestamp;

      for (final e in callEntries) {
        log(
          '[CallLogController] Processing CallLogEntry: Number=${e.number}, TS=${e.timestamp}, Type=${e.callType?.name}, Dur=${e.duration}, Name=${e.name}',
        );
        if (e.number != null && e.number!.isNotEmpty && e.timestamp != null) {
          final entryTimestamp = localEpochToUtcEpoch(e.timestamp!);

          newFetchedLogs.add({
            'number': normalizePhone(e.number!),
            'callType': e.callType?.name ?? 'UNKNOWN',
            'timestamp': entryTimestamp,
            'duration': e.duration ?? 0,
            'name': e.name ?? '',
          });
          if (entryTimestamp > latestTimestampInBatch) {
            latestTimestampInBatch = entryTimestamp;
          }
        }
      }
      log(
        '[CallLogController] Processed ${newFetchedLogs.length} new call log entries for newFetchedLogs list.',
      );

      if (newFetchedLogs.isNotEmpty) {
        final logsForServer = CallLogController.prepareLogsForServer(
          newFetchedLogs,
        );
        if (logsForServer.isNotEmpty) {
          log(
            '[CallLogController] Uploading ${logsForServer.length} call logs to server.',
          );
          try {
            bool uploadSuccess = await LogApi.updateCallLog(logsForServer);
            if (uploadSuccess) {
              log(
                '[CallLogController] Call log upload successful. Updating last sync timestamp to $latestTimestampInBatch',
              );
              await _settingsRepository.setLastCallLogSyncTimestamp(
                latestTimestampInBatch,
              );
            } else {
              log(
                '[CallLogController] Call log upload failed (API returned false).',
              );
            }
          } catch (apiError) {
            log(
              '[CallLogController] Error uploading call logs (sync): $apiError',
            );
          }
        }

        await _callLogRepository.saveCallLogs(newFetchedLogs);
        log(
          '[CallLogController] Saved ${newFetchedLogs.length} new call logs to local repository.',
        );
      } else {
        log(
          '[CallLogController] No new call logs to process from platform query after processing.',
        );
      }

      _callLogs = await _callLogRepository.getAllCallLogs();
      log(
        '[CallLogController] Updated _callLogs with ${_callLogs.length} entries from repository.',
      );
    } catch (e, st) {
      log('[CallLogController] Error in refreshCallLogs: $e\n$st');
    } finally {
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
        .where((log) => !log['callType'].startsWith('UNKNOWN'))
        .toList();
  }
}
