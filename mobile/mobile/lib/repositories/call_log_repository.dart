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

  /// 모든 통화 기록 데이터를 삭제합니다 (로그아웃 등에서 사용).
  Future<void> clearCallLogs();
}

/// Hive를 사용하여 CallLogRepository 인터페이스를 구현하는 클래스
class HiveCallLogRepository implements CallLogRepository {
  final Box<Map<String, dynamic>> _callLogsBox;

  HiveCallLogRepository(this._callLogsBox);

  String _generateCallLogKey(Map<String, dynamic> callLogMap) {
    final timestamp = callLogMap['timestamp'];
    final number = callLogMap['number'];
    final callType = callLogMap['callType']; // 키의 고유성을 위해 callType도 포함
    if (timestamp != null && number != null && callType != null) {
      final safeNumberString = number.toString().replaceAll(
        RegExp(r'[^a-zA-Z0-9_+-]'),
        '_',
      );
      return 'calllog_${timestamp}_${safeNumberString}_$callType';
    }
    return 'calllog_unknown_${DateTime.now().millisecondsSinceEpoch}_${callLogMap.hashCode}';
  }

  @override
  Future<List<Map<String, dynamic>>> getAllCallLogs() async {
    try {
      final List<Map<String, dynamic>> resultList = [];
      for (final dynamic valueFromBox in _callLogsBox.values) {
        if (valueFromBox is Map) {
          final Map<String, dynamic> correctlyTypedMap = valueFromBox.map(
            (key, value) => MapEntry(key.toString(), value),
          );
          resultList.add(correctlyTypedMap);
        } else {
          log(
            '[HiveCallLogRepository] getAllCallLogs: Unexpected item type: ${valueFromBox.runtimeType}. Value: $valueFromBox',
          );
        }
      }
      log(
        '[HiveCallLogRepository] getAllCallLogs: Successfully fetched ${resultList.length} call logs from Hive.',
      );
      return resultList;
    } catch (e, s) {
      log(
        '[HiveCallLogRepository] Error getting all call logs: $e',
        stackTrace: s,
      );
      return [];
    }
  }

  @override
  Future<void> saveCallLogs(List<Map<String, dynamic>> newCallLogs) async {
    try {
      if (!_callLogsBox.isOpen) {
        log('[HiveCallLogRepository] saveCallLogs: Box is not open!');
        return;
      }
      await _callLogsBox.clear();
      final Map<String, Map<String, dynamic>> entriesToPut = {};
      for (final callLog in newCallLogs) {
        final String key = _generateCallLogKey(callLog);
        entriesToPut[key] = callLog;
      }
      if (entriesToPut.isNotEmpty) {
        await _callLogsBox.putAll(entriesToPut);
        log(
          '[HiveCallLogRepository] Saved ${entriesToPut.length} call logs (24시간 이내 전체 덮어쓰기).',
        );
      }
    } catch (e, s) {
      log('[HiveCallLogRepository] Error saving call logs: $e', stackTrace: s);
      rethrow;
    }
  }

  @override
  Future<void> clearCallLogs() async {
    try {
      if (!_callLogsBox.isOpen) {
        log('[HiveCallLogRepository] clearCallLogs: Box is not open!');
        return;
      }
      await _callLogsBox.clear();
      log(
        '[HiveCallLogRepository] Cleared all call logs from box: ${_callLogsBox.name}',
      );
    } catch (e, s) {
      log(
        '[HiveCallLogRepository] Error clearing call logs: $e',
        stackTrace: s,
      );
    }
  }
}

// 의존성 주입 설정 시 Box<String> 대신 Box를 사용하거나,
// 이전처럼 Box<Map<dynamic, dynamic>>을 사용하고 싶다면
// save 시 Map<String, dynamic>을 다시 Map<dynamic, dynamic>으로 변환해야 하지만,
// 여기서는 단순화를 위해 Box와 JSON 문자열을 사용합니다.
// 예시:
// Future<void> setupCallLogRepository() async {
//   final Box callLogsBox = await Hive.openBox(_callLogsBoxName);
//   getIt.registerSingleton<CallLogRepository>(HiveCallLogRepository(callLogsBox));
// }
