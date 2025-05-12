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

  List<Map<String, dynamic>> get callLogs => _callLogs;
  bool get isLoading => _isLoading;

  // CallLogController(this._callLogRepository, this._settingsRepository) {
  CallLogController(this._callLogRepository) {
    // 생성자에서 SettingsRepository 제거
    loadSavedCallLogs();
  }

  Future<void> loadSavedCallLogs() async {
    if (_isLoading) return;
    _isLoading = true;
    notifyListeners();
    try {
      _callLogs = await _callLogRepository.getAllCallLogs();
    } catch (e) {
      log('[CallLogController] Error loading saved call logs: $e');
      _callLogs = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshCallLogs() async {
    if (_isLoading) {
      log('[CallLogController] Already refreshing call logs, skipping.');
      return;
    }
    _isLoading = true;
    notifyListeners();

    List<Map<String, dynamic>> previouslySavedLogs = [];
    try {
      // 0. (선택적) UI 즉각 반응을 위해 먼저 저장된 로그를 한번 로드 (하지만 중복 호출될 수 있으므로 아래 로직과 통합 고려)
      // 또는, 서버 업로드 비교용으로만 사용
      previouslySavedLogs = await _callLogRepository.getAllCallLogs();

      // 1. 최근 24시간 범위 설정
      final now = DateTime.now();
      final queryFromTimestamp =
          now.subtract(const Duration(hours: 24)).millisecondsSinceEpoch;
      final queryToTimestamp = now.millisecondsSinceEpoch;

      Iterable<CallLogEntry> callEntries = await CallLog.query(
        dateFrom: queryFromTimestamp,
        dateTo: queryToTimestamp,
      );

      // 2. 가져온 최근 24시간 로그를 내부 리스트(_callLogs)로 즉시 업데이트 및 UI 갱신
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

      _callLogs = recentLogs; // UI에 먼저 반영
      notifyListeners();

      // 3. 이전 저장된 로그와 비교하여 새로 추가된 로그만 서버에 비동기 업로드
      final Set<String> previouslySavedLogIds =
          previouslySavedLogs.map((log) {
            return "${log['timestamp']}_${log['number']}_${log['callType']}"; // 고유 ID 생성 방식 개선
          }).toSet();

      final List<Map<String, dynamic>> newLogsToUpload =
          recentLogs.where((log) {
            final currentLogId =
                "${log['timestamp']}_${log['number']}_${log['callType']}";
            return !previouslySavedLogIds.contains(currentLogId);
          }).toList();

      if (newLogsToUpload.isNotEmpty) {
        final logsForServer = CallLogController.prepareLogsForServer(
          newLogsToUpload,
        );
        if (logsForServer.isNotEmpty) {
          // 서버 업로드는 비동기로 처리하고 결과에 따라 UI를 직접 변경하지 않음 (오류 로깅만)
          LogApi.updateCallLog(logsForServer)
              .then((uploadSuccess) {
                if (!uploadSuccess) {
                  log(
                    '[CallLogController] Call log upload failed (API returned false) for new logs.',
                  );
                }
              })
              .catchError((apiError, stackTrace) {
                log(
                  '[CallLogController] Error uploading new call logs (async): $apiError\n$stackTrace',
                );
              });
        }
      }

      // 4. 최근 24시간 로그 전체를 저장소에 덮어쓰기
      await _callLogRepository.saveCallLogs(recentLogs);
    } catch (e, st) {
      log('[CallLogController] Error in refreshCallLogs: $e\n$st');
    } finally {
      _isLoading = false;
      notifyListeners(); // 로딩 종료 및 최종 상태 반영
    }
  }

  // prepareLogsForServer 함수는 동일하게 유지 (필요시 내용 수정)
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
