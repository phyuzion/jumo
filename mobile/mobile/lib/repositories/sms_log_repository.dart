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

  /// 24시간이 지난 오래된 SMS 기록을 삭제합니다.
  Future<void> purgeOldSmsLogs();
}

/// Hive를 사용하여 SmsLogRepository 인터페이스를 구현하는 클래스
class HiveSmsLogRepository implements SmsLogRepository {
  final Box<Map<dynamic, dynamic>> _smsLogsBox;

  HiveSmsLogRepository(this._smsLogsBox);

  // SMS를 위한 고유 키 생성.
  // SmsController에서 nativeSmsMap을 만들 때 'native_id' 필드에 네이티브 SMS ID를 넣어준다고 가정합니다.
  String _generateSmsKey(Map<String, dynamic> smsMap) {
    final nativeId = smsMap['native_id']; // SmsController에서 추가한 필드
    final date = smsMap['date'];
    final address = smsMap['address'];

    if (nativeId != null && nativeId != 0) {
      return 'sms_nid_${nativeId}'; // 네이티브 ID가 있으면 우선 사용 (가장 확실한 고유키)
    }
    // 네이티브 ID가 없거나 0인 경우 (혹은 이전 데이터 호환 등), date와 address 조합 사용
    // 이 경우 완벽한 고유성을 보장하지 못할 수 있으므로 주의.
    if (date != null && address != null) {
      return 'sms_dateaddr_${date}_${address.hashCode}';
    }
    // 최후의 수단 (이런 경우는 거의 없어야 함)
    return 'sms_fallback_${DateTime.now().millisecondsSinceEpoch}_${smsMap.hashCode}';
  }

  @override
  Future<List<Map<String, dynamic>>> getAllSmsLogs() async {
    try {
      // Hive 박스에 저장된 모든 값(Map)을 가져와 List로 변환합니다.
      return _smsLogsBox.values
          .map((dynamic e) {
            if (e is Map) {
              return Map<String, dynamic>.from(e);
            } else {
              log(
                '[HiveSmsLogRepository] getAllSmsLogs: Unexpected item type: ${e.runtimeType}',
              );
              return <String, dynamic>{}; // 잘못된 타입은 빈 맵으로 처리
            }
          })
          .where((e) => e.isNotEmpty)
          .toList(); // 빈 맵은 제외
    } catch (e) {
      log('[HiveSmsLogRepository] Error getting all SMS logs: $e');
      return [];
    }
  }

  @override
  Future<void> saveSmsLogs(List<Map<String, dynamic>> newSmsLogs) async {
    try {
      final Map<String, Map<dynamic, dynamic>> entriesToPut = {};
      for (final smsMap in newSmsLogs) {
        // 각 SMS에 대한 고유 키 생성
        final String key = _generateSmsKey(smsMap);
        // Hive에 저장할 값은 Map<dynamic, dynamic>이어야 하므로 변환
        entriesToPut[key] = Map<dynamic, dynamic>.from(smsMap);
      }

      // 생성된 모든 항목을 한 번에 저장 (putAll 사용)
      if (entriesToPut.isNotEmpty) {
        await _smsLogsBox.putAll(entriesToPut);
        log(
          '[HiveSmsLogRepository] Saved/Updated ${entriesToPut.length} SMS logs using individual keys.',
        );
      }

      // 저장 후 오래된 로그 삭제
      await purgeOldSmsLogs();
    } catch (e) {
      log('[HiveSmsLogRepository] Error saving SMS logs: $e');
      rethrow; // 오류를 다시 던져 호출한 쪽에서 알 수 있도록 함
    }
  }

  @override
  Future<void> clearSmsLogs() async {
    try {
      await _smsLogsBox.clear();
      log(
        '[HiveSmsLogRepository] Cleared all SMS logs from box: ${_smsLogsBox.name}',
      );
    } catch (e) {
      log('[HiveSmsLogRepository] Error clearing SMS logs: $e');
    }
  }

  @override
  Future<void> purgeOldSmsLogs() async {
    try {
      final cutoffTime =
          DateTime.now()
              .subtract(const Duration(days: 1))
              .millisecondsSinceEpoch;
      int deleteCount = 0;

      final List<String> keysToDelete = [];
      // Hive 박스의 모든 키를 순회
      for (var key in _smsLogsBox.keys) {
        final smsMap = _smsLogsBox.get(
          key,
        ); // 키를 사용하여 Map<dynamic, dynamic> 가져오기
        if (smsMap != null) {
          // date 필드가 int 타입의 타임스탬프라고 가정
          final smsDate = smsMap['date'] as int?;
          if (smsDate != null && smsDate < cutoffTime) {
            keysToDelete.add(key as String); // 삭제할 키 목록에 추가
          }
        }
      }

      if (keysToDelete.isNotEmpty) {
        await _smsLogsBox.deleteAll(keysToDelete); // 수집된 키들을 한 번에 삭제
        deleteCount = keysToDelete.length;
      }
      log(
        '[HiveSmsLogRepository] Purged $deleteCount old SMS logs (older than 24 hours).',
      );
    } catch (e) {
      log('[HiveSmsLogRepository] Error purging old SMS logs: $e');
    }
  }
}

// 의존성 주입 설정 (예: main.dart 또는 service_locator.dart)에서 Hive 박스를 열고 Repository를 등록해야 합니다.
// 예시:
// Future<void> setupSmsLogRepository() async {
//   final Box<Map<dynamic, dynamic>> smsLogsBox = await Hive.openBox<Map<dynamic, dynamic>>(_smsLogsBoxName);
//   getIt.registerSingleton<SmsLogRepository>(HiveSmsLogRepository(smsLogsBox));
// }
