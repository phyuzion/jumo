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

  Future<void> loadSavedCallLogs() async {
    log('[CallLogController.loadSavedCallLogs] Started.');
    if (_isLoading) {
      log('[CallLogController.loadSavedCallLogs] Already loading, skipping.');
      return;
    }
    _isLoading = true;
    // notifyListeners(); // 시작 시점의 notify 제거 (finally에서 한번만)

    // 변경 비교를 위해 현재 _callLogs 상태의 간단한 표현 (예: 길이와 해시코드 조합)을 저장
    // 또는 각 Map을 ID화하여 Set으로 만들어 비교할 수도 있음
    // 여기서는 더 확실한 비교를 위해 전체 리스트를 복사해둠 (메모리 주의)
    List<Map<String, dynamic>> oldLogsSnapshot = List.from(_callLogs);
    bool dataActuallyChanged = false;

    try {
      final loadedLogs = await _callLogRepository.getAllCallLogs();
      log(
        '[CallLogController.loadSavedCallLogs] Loaded ${loadedLogs.length} logs from repository.',
      );

      // 데이터 변경 여부 확인 (더 정교한 비교 로직 필요 시 수정)
      // 여기서는 flutter/foundation.dart의 listEquals와 mapEquals를 활용하는 시도
      // listEquals는 List<Map>에 대해 원하는 대로 동작하지 않을 수 있으므로, 각 요소를 비교해야 함
      if (oldLogsSnapshot.length != loadedLogs.length) {
        dataActuallyChanged = true;
      } else {
        // 길이가 같으면 각 요소 비교 (순서가 중요하다고 가정)
        for (int i = 0; i < oldLogsSnapshot.length; i++) {
          if (!mapEquals(oldLogsSnapshot[i], loadedLogs[i])) {
            dataActuallyChanged = true;
            break;
          }
        }
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
      // 오류 발생 시 _isLoading은 finally에서 false가 되고, 데이터는 변경되지 않음
    } finally {
      _isLoading = false;
      log(
        '[CallLogController.loadSavedCallLogs] Before final notifyListeners (isLoading: false, logs: ${_callLogs.length}, dataActuallyChangedInThisRun: $dataActuallyChanged)',
      );
      notifyListeners(); // isLoading 상태 변경 및 데이터 변경(있었다면)을 한 번에 알림
      log('[CallLogController.loadSavedCallLogs] Finished.');
    }
  }

  Future<void> refreshCallLogs() async {
    log('[CallLogController.refreshCallLogs] Started.');
    if (_isLoading) {
      log('[CallLogController.refreshCallLogs] Already refreshing, skipping.');
      return;
    }
    _isLoading = true;
    log(
      '[CallLogController.refreshCallLogs] Before notifyListeners (isLoading: true)',
    );
    notifyListeners();

    List<Map<String, dynamic>> oldCallLogsSnapshot = List.from(_callLogs);
    bool dataHasChanged = false;

    try {
      log(
        '[CallLogController.refreshCallLogs] Getting previously saved logs from repository (for diff)...',
      );
      List<Map<String, dynamic>> previouslySavedLogsForDiff =
          await _callLogRepository.getAllCallLogs();
      log(
        '[CallLogController.refreshCallLogs] Got ${previouslySavedLogsForDiff.length} previously saved logs for diff.',
      );

      final now = DateTime.now();
      final queryFromTimestamp =
          now.subtract(const Duration(hours: 24)).millisecondsSinceEpoch;
      final queryToTimestamp = now.millisecondsSinceEpoch;

      log(
        '[CallLogController.refreshCallLogs] Querying native CallLog from $queryFromTimestamp to $queryToTimestamp...',
      );
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

      if (oldCallLogsSnapshot.length != recentLogs.length ||
          (recentLogs.isNotEmpty &&
              !mapEquals(
                oldCallLogsSnapshot.safeElementAt(0),
                recentLogs.safeElementAt(0),
              )) ||
          (recentLogs.length > 1 &&
              !mapEquals(
                oldCallLogsSnapshot.safeElementAt(
                  oldCallLogsSnapshot.length - 1,
                ),
                recentLogs.safeElementAt(recentLogs.length - 1),
              ))) {
        _callLogs = recentLogs;
        dataHasChanged = true;
        log(
          '[CallLogController.refreshCallLogs] _callLogs updated as data changed.',
        );
      } else {
        log(
          '[CallLogController.refreshCallLogs] Length is same, assuming no change for now. (For more precise check, implement deep list comparison)',
        );
      }

      final Set<String> previouslySavedLogIdsForDiff =
          previouslySavedLogsForDiff.map((logEntry) {
            return "${logEntry['timestamp']}_${logEntry['number']}_${logEntry['callType']}";
          }).toSet();

      final List<Map<String, dynamic>> newLogsToUpload =
          recentLogs.where((logEntry) {
            final currentLogId =
                "${logEntry['timestamp']}_${logEntry['number']}_${logEntry['callType']}";
            return !previouslySavedLogIdsForDiff.contains(currentLogId);
          }).toList();
      log(
        '[CallLogController.refreshCallLogs] Found ${newLogsToUpload.length} new logs to upload to server (based on diff with previously saved state).',
      );

      if (newLogsToUpload.isNotEmpty) {
        final logsForServer = CallLogController.prepareLogsForServer(
          newLogsToUpload,
        );
        log(
          '[CallLogController.refreshCallLogs] Prepared ${logsForServer.length} logs for server.',
        );
        if (logsForServer.isNotEmpty) {
          log(
            '[CallLogController.refreshCallLogs] Uploading logs to server (async)...',
          );
          LogApi.updateCallLog(logsForServer)
              .then((uploadSuccess) {
                if (!uploadSuccess) {
                  log(
                    '[CallLogController.refreshCallLogs] Call log upload failed (API returned false) for new logs.',
                  );
                } else {
                  log(
                    '[CallLogController.refreshCallLogs] Call log upload successful for new logs.',
                  );
                }
              })
              .catchError((apiError, stackTrace) {
                log(
                  '[CallLogController.refreshCallLogs] Error uploading new call logs (async): $apiError\n$stackTrace',
                );
              });
        }
      }

      log(
        '[CallLogController.refreshCallLogs] Saving ${recentLogs.length} recent logs to repository (full overwrite)...',
      );
      await _callLogRepository.saveCallLogs(recentLogs);
      log(
        '[CallLogController.refreshCallLogs] Saved recent logs to repository.',
      );
    } catch (e, st) {
      log('[CallLogController.refreshCallLogs] Error: $e\n$st');
    } finally {
      _isLoading = false;
      log(
        '[CallLogController.refreshCallLogs] Before final notifyListeners (isLoading: false, logs: ${_callLogs.length}, dataActuallyChangedInThisRun: $dataHasChanged)',
      );
      notifyListeners();
      log('[CallLogController.refreshCallLogs] Finished.');
    }
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

extension SafeList<E> on List<E> {
  E? safeElementAt(int index) {
    if (index < 0 || index >= length) {
      return null;
    }
    return elementAt(index);
  }
}
