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

  /// SMS 기록 목록을 저장합니다. (새로운 로그를 추가/업데이트하고 오래된 로그는 정리합니다)
  Future<void> saveSmsLogs(List<Map<String, dynamic>> newSmsLogs);

  /// 모든 SMS 기록 데이터를 삭제합니다 (로그아웃 등에서 사용).
  Future<void> clearSmsLogs();
}

/// Hive를 사용하여 SmsLogRepository 인터페이스를 구현하는 클래스
class HiveSmsLogRepository implements SmsLogRepository {
  final Box<Map<dynamic, dynamic>> _smsLogsBox;

  HiveSmsLogRepository(this._smsLogsBox);

  // SMS를 위한 고유 키 생성.
  String _generateSmsKey(Map<String, dynamic> smsMap) {
    final date = smsMap['date'];
    final address = smsMap['address'];

    if (date != null && address != null) {
      return "msg_key_${date}_${address.hashCode}";
    }
    return "msg_fallback_${DateTime.now().millisecondsSinceEpoch}_${smsMap.hashCode}";
  }

  @override
  Future<List<Map<String, dynamic>>> getAllSmsLogs() async {
    try {
      final List<Map<String, dynamic>> resultList = [];
      for (final dynamic valueFromBoxDynamic in _smsLogsBox.values) {
        if (valueFromBoxDynamic is Map) {
          try {
            final Map<String, dynamic> correctlyTypedMap = valueFromBoxDynamic
                .map((key, value) => MapEntry(key.toString(), value));
            resultList.add(correctlyTypedMap);
          } catch (conversionError) {
            log(
              '[HiveSmsLogRepository] Error converting map entry: $conversionError. Entry: $valueFromBoxDynamic',
            );
          }
        } else {
          log(
            '[HiveSmsLogRepository] getAllSmsLogs: Unexpected item type: ${valueFromBoxDynamic.runtimeType}. Value: $valueFromBoxDynamic',
          );
        }
      }
      log(
        '[HiveSmsLogRepository] getAllSmsLogs: Successfully fetched ${resultList.length} SMS logs from Hive.',
      );
      return resultList;
    } catch (e, s) {
      log(
        '[HiveSmsLogRepository] Error getting all SMS logs: $e',
        stackTrace: s,
      );
      return [];
    }
  }

  @override
  Future<void> saveSmsLogs(List<Map<String, dynamic>> newSmsLogs) async {
    try {
      if (!_smsLogsBox.isOpen) {
        log('[HiveSmsLogRepository] saveSmsLogs: Box is not open!');
        return;
      }

      // 기존 데이터를 모두 지우지 않고, 개별 항목 업데이트 방식으로 변경
      // Hive에 데이터 저장시 키-값 쌍으로 개별 업데이트
      final Map<String, Map<String, dynamic>> entriesToPut = {};
      int addCount = 0;
      int updateCount = 0;

      // 새 메시지 항목 처리
      for (final smsMap in newSmsLogs) {
        final String key = _generateSmsKey(smsMap);

        // 이미 존재하는 키인지 확인
        if (_smsLogsBox.containsKey(key)) {
          updateCount++;
        } else {
          addCount++;
        }

        entriesToPut[key] = smsMap;
      }

      // 개별 항목 저장
      if (entriesToPut.isNotEmpty) {
        await _smsLogsBox.putAll(
          entriesToPut.cast<String, Map<dynamic, dynamic>>(),
        );
        log(
          '[HiveSmsLogRepository] Saved ${entriesToPut.length} SMS logs (새 항목: $addCount, 업데이트: $updateCount).',
        );
      }

      // 필요한 경우 오래된 데이터 정리
      final DateTime oneDayAgo = DateTime.now().subtract(
        const Duration(days: 1),
      );
      final keysToDelete = <String>[];

      _smsLogsBox.keys.forEach((key) {
        if (key is String) {
          final value = _smsLogsBox.get(key);
          if (value != null && value is Map) {
            final date = value['date'];
            if (date != null && date is int) {
              final msgDateTime = DateTime.fromMillisecondsSinceEpoch(date);
              if (msgDateTime.isBefore(oneDayAgo)) {
                keysToDelete.add(key);
              }
            }
          }
        }
      });

      if (keysToDelete.isNotEmpty) {
        await _smsLogsBox.deleteAll(keysToDelete);
        log(
          '[HiveSmsLogRepository] Cleaned up ${keysToDelete.length} old SMS logs (1일 이전).',
        );
      }
    } catch (e, s) {
      log('[HiveSmsLogRepository] Error saving SMS logs: $e', stackTrace: s);
      rethrow;
    }
  }

  @override
  Future<void> clearSmsLogs() async {
    try {
      if (!_smsLogsBox.isOpen) {
        log('[HiveSmsLogRepository] clearSmsLogs: Box is not open!');
        return;
      }
      await _smsLogsBox.clear();
      log(
        '[HiveSmsLogRepository] Cleared all SMS logs from box: ${_smsLogsBox.name}',
      );
    } catch (e, s) {
      log('[HiveSmsLogRepository] Error clearing SMS logs: $e', stackTrace: s);
    }
  }
}

// 의존성 주입 설정 (예: main.dart 또는 service_locator.dart)에서 Hive 박스를 열고 Repository를 등록해야 합니다.
// 예시:
// Future<void> setupSmsLogRepository() async {
//   final Box<Map<dynamic, dynamic>> smsLogsBox = await Hive.openBox<Map<dynamic, dynamic>>(_smsLogsBoxName);
//   getIt.registerSingleton<SmsLogRepository>(HiveSmsLogRepository(smsLogsBox));
// }
