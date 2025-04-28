import 'dart:convert';
import 'dart:developer';
import 'package:hive_ce/hive.dart';

// Hive 박스 이름 정의
const String _smsLogsBoxName = 'sms_logs';

/// SMS 기록 데이터 접근을 위한 추상 클래스 (인터페이스)
abstract class SmsLogRepository {
  /// 저장된 모든 SMS 기록 목록을 가져옵니다.
  /// 반환값: List<Map<String, dynamic>> 형태의 SMS 기록 목록
  Future<List<Map<String, dynamic>>> getAllSmsLogs();

  /// SMS 기록 목록을 저장합니다. (기존 데이터를 덮어씁니다)
  Future<void> saveSmsLogs(List<Map<String, dynamic>> smsLogs);

  /// 모든 SMS 기록 데이터를 삭제합니다 (로그아웃 등에서 사용).
  Future<void> clearSmsLogs();
}

/// Hive를 사용하여 SmsLogRepository 인터페이스를 구현하는 클래스
class HiveSmsLogRepository implements SmsLogRepository {
  final Box _smsLogsBox;

  HiveSmsLogRepository(this._smsLogsBox);

  @override
  Future<List<Map<String, dynamic>>> getAllSmsLogs() async {
    try {
      final logsJson = _smsLogsBox.get('logs') as String?;
      if (logsJson != null) {
        final decodedList = jsonDecode(logsJson);
        if (decodedList is List) {
          return decodedList.map((e) {
            if (e is Map) {
              return Map<String, dynamic>.from(e);
            } else {
              log(
                '[HiveSmsLogRepository] Unexpected item type in SMS logs: ${e.runtimeType}',
              );
              return <String, dynamic>{};
            }
          }).toList();
        }
      }
      return [];
    } catch (e) {
      log('[HiveSmsLogRepository] Error getting all SMS logs: $e');
      return [];
    }
  }

  @override
  Future<void> saveSmsLogs(List<Map<String, dynamic>> smsLogs) async {
    try {
      final logsJson = jsonEncode(smsLogs);
      await _smsLogsBox.put('logs', logsJson);
    } catch (e) {
      log('[HiveSmsLogRepository] Error saving SMS logs: $e');
      rethrow;
    }
  }

  @override
  Future<void> clearSmsLogs() async {
    await _smsLogsBox.clear();
  }
}
