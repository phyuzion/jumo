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

  /// 통화 기록 목록을 저장합니다. (기존 데이터를 덮어씁니다)
  Future<void> saveCallLogs(List<Map<String, dynamic>> callLogs);

  /// 새로운 통화 기록을 추가합니다.
  // Future<void> addCallLog(Map<String, dynamic> callLog); // 필요 시 추가

  /// 모든 통화 기록 데이터를 삭제합니다 (로그아웃 등에서 사용).
  Future<void> clearCallLogs();
}

/// Hive를 사용하여 CallLogRepository 인터페이스를 구현하는 클래스
class HiveCallLogRepository implements CallLogRepository {
  final Box _callLogsBox;

  HiveCallLogRepository(this._callLogsBox);

  @override
  Future<List<Map<String, dynamic>>> getAllCallLogs() async {
    try {
      // Hive Box에는 'logs' 키 아래에 JSON 문자열로 저장되어 있을 수 있음
      final logsJson = _callLogsBox.get('logs') as String?;
      if (logsJson != null) {
        final decodedList = jsonDecode(logsJson);
        if (decodedList is List) {
          // 각 항목이 Map<String, dynamic>인지 확인 후 캐스팅
          return decodedList.map((e) {
            if (e is Map) {
              return Map<String, dynamic>.from(e);
            } else {
              // 예상치 못한 타입 처리 (예: 로깅 후 빈 Map 반환)
              log(
                '[HiveCallLogRepository] Unexpected item type in call logs: ${e.runtimeType}',
              );
              return <String, dynamic>{};
            }
          }).toList();
        }
      }
      return []; // logs 키가 없거나 JSON 디코딩 실패 시 빈 리스트 반환
    } catch (e) {
      log('[HiveCallLogRepository] Error getting all call logs: $e');
      return [];
    }
  }

  @override
  Future<void> saveCallLogs(List<Map<String, dynamic>> callLogs) async {
    try {
      // 데이터를 JSON 문자열로 인코딩하여 'logs' 키에 저장
      final logsJson = jsonEncode(callLogs);
      await _callLogsBox.put('logs', logsJson);
    } catch (e) {
      log('[HiveCallLogRepository] Error saving call logs: $e');
      // 오류 처리 (예: 예외 다시 던지기)
      rethrow;
    }
  }

  @override
  Future<void> clearCallLogs() async {
    await _callLogsBox.clear();
  }
}
