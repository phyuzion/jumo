import 'dart:convert';
import 'dart:developer';
import 'package:hive_ce/hive.dart';

// Hive 박스 이름 정의
const String _callLogsBoxName = 'call_logs';

/// 통화 기록 데이터 접근을 위한 추상 클래스 (인터페이스)
abstract class CallLogRepository {
  /// 저장된 모든 통화 기록 목록을 가져옵니다.
  /// 반환값: List<Map<String, dynamic>> 형태의 통화 기록 목록
  Future<List<Map<String, dynamic>>> getAllCallLogs();

  /// 통화 기록 목록을 저장합니다. (새로운 로그를 추가/업데이트하고 오래된 로그는 정리합니다)
  Future<void> saveCallLogs(List<Map<String, dynamic>> newCallLogs);

  /// 새로운 통화 기록을 추가합니다.
  // Future<void> addCallLog(Map<String, dynamic> callLog); // 필요 시 추가

  /// 모든 통화 기록 데이터를 삭제합니다 (로그아웃 등에서 사용).
  Future<void> clearCallLogs();

  /// 24시간이 지난 오래된 통화 기록을 삭제합니다.
  Future<void> purgeOldCallLogs();
}

/// Hive를 사용하여 CallLogRepository 인터페이스를 구현하는 클래스
class HiveCallLogRepository implements CallLogRepository {
  final Box<Map<dynamic, dynamic>> _callLogsBox; // 값 타입을 Map으로 명시

  HiveCallLogRepository(this._callLogsBox);

  // 통화 기록을 위한 고유 키 생성 (타임스탬프와 번호 조합)
  String _generateCallLogKey(Map<String, dynamic> callLogMap) {
    final timestamp = callLogMap['timestamp'];
    final number = callLogMap['number'];
    if (timestamp != null && number != null) {
      // 번호에 특수문자가 있을 수 있으므로, 해시코드 또는 안전한 문자만 사용하도록 처리
      final numberString = number.toString().replaceAll(
        RegExp(r'[^a-zA-Z0-9]'),
        '',
      ); // 간단한 예시
      return 'calllog_\${timestamp}_$numberString';
    }
    return 'calllog_unknown_\${DateTime.now().millisecondsSinceEpoch}_\${callLogMap.hashCode}';
  }

  @override
  Future<List<Map<String, dynamic>>> getAllCallLogs() async {
    try {
      return _callLogsBox.values
          .map((dynamic e) {
            if (e is Map) {
              return Map<String, dynamic>.from(e);
            } else {
              log(
                '[HiveCallLogRepository] getAllCallLogs: Unexpected item type: ${e.runtimeType}',
              );
              return <String, dynamic>{};
            }
          })
          .where((e) => e.isNotEmpty)
          .toList();
    } catch (e) {
      log('[HiveCallLogRepository] Error getting all call logs: $e');
      return [];
    }
  }

  @override
  Future<void> saveCallLogs(List<Map<String, dynamic>> newCallLogs) async {
    try {
      final Map<String, Map<dynamic, dynamic>> entriesToPut = {};
      for (final callLogMap in newCallLogs) {
        final String key = _generateCallLogKey(callLogMap);
        entriesToPut[key] = Map<dynamic, dynamic>.from(callLogMap);
      }

      if (entriesToPut.isNotEmpty) {
        await _callLogsBox.putAll(entriesToPut);
        log(
          '[HiveCallLogRepository] Saved/Updated ${entriesToPut.length} call logs using individual keys.',
        );
      }

      await purgeOldCallLogs(); // 저장 후 오래된 로그 정리
    } catch (e) {
      log('[HiveCallLogRepository] Error saving call logs: $e');
      rethrow;
    }
  }

  @override
  Future<void> clearCallLogs() async {
    try {
      await _callLogsBox.clear();
      log(
        '[HiveCallLogRepository] Cleared all call logs from box: ${_callLogsBox.name}',
      );
    } catch (e) {
      log('[HiveCallLogRepository] Error clearing call logs: $e');
    }
  }

  @override
  Future<void> purgeOldCallLogs() async {
    try {
      final cutoffTime =
          DateTime.now()
              .subtract(const Duration(days: 1))
              .millisecondsSinceEpoch;
      int deleteCount = 0;

      final List<String> keysToDelete = [];
      for (var key in _callLogsBox.keys) {
        final callLogMap = _callLogsBox.get(key);
        if (callLogMap != null) {
          final callTimestamp = callLogMap['timestamp'] as int?;
          if (callTimestamp != null && callTimestamp < cutoffTime) {
            keysToDelete.add(key as String);
          }
        }
      }

      if (keysToDelete.isNotEmpty) {
        await _callLogsBox.deleteAll(keysToDelete);
        deleteCount = keysToDelete.length;
      }
      log(
        '[HiveCallLogRepository] Purged $deleteCount old call logs (older than 24 hours).',
      );
    } catch (e) {
      log('[HiveCallLogRepository] Error purging old call logs: $e');
    }
  }
}

// 의존성 주입 설정 (예: main.dart 또는 service_locator.dart)에서 Hive 박스를 열고 Repository를 등록해야 합니다.
// 예시:
// Future<void> setupCallLogRepository() async {
//   final Box<Map<dynamic, dynamic>> callLogsBox = await Hive.openBox<Map<dynamic, dynamic>>(_callLogsBoxName);
//   getIt.registerSingleton<CallLogRepository>(HiveCallLogRepository(callLogsBox));
// }
