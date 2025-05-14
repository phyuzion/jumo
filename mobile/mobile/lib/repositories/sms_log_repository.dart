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
  // SmsController에서 nativeSmsMap을 만들 때 'native_id' 필드에 네이티브 SMS ID를 넣어준다고 가정합니다.
  String _generateSmsKey(Map<String, dynamic> smsMap) {
    final nativeId = smsMap['native_id'];
    final date = smsMap['date'];
    final address = smsMap['address'];
    if (nativeId != null && nativeId != 0 && nativeId.toString().isNotEmpty) {
      return 'sms_nid_${nativeId}';
    }
    if (date != null && address != null) {
      return 'sms_dateaddr_${date}_${address.hashCode}';
    }
    return 'sms_fallback_${DateTime.now().millisecondsSinceEpoch}_${smsMap.hashCode}';
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
      await _smsLogsBox.clear();
      final Map<String, Map<String, dynamic>> entriesToPut = {};
      for (final smsMap in newSmsLogs) {
        final String key = _generateSmsKey(smsMap);
        entriesToPut[key] = smsMap;
      }
      if (entriesToPut.isNotEmpty) {
        await _smsLogsBox.putAll(
          entriesToPut.cast<String, Map<dynamic, dynamic>>(),
        );
        log(
          '[HiveSmsLogRepository] Saved ${entriesToPut.length} SMS logs (24시간 이내 전체 덮어쓰기).',
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
