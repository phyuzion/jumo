import 'dart:developer';
import 'package:hive_ce/hive.dart';

// Hive 박스 이름 정의
const String _syncStateBoxName = 'last_sync_state';

/// 동기화 상태 데이터 접근을 위한 추상 클래스 (인터페이스)
abstract class SyncStateRepository {
  /// 특정 키에 대한 마지막 동기화 타임스탬프(int, epoch milliseconds)를 가져옵니다.
  /// 키가 없으면 0을 반환합니다.
  Future<int> getLastSyncTimestamp(String key);

  /// 특정 키에 대한 마지막 동기화 타임스탬프를 설정합니다.
  Future<void> setLastSyncTimestamp(String key, int timestamp);

  /// 특정 키에 대한 동기화 상태를 삭제합니다.
  Future<void> deleteSyncTimestamp(String key);

  /// 모든 동기화 상태 데이터를 삭제합니다 (로그아웃 등에서 사용).
  Future<void> clearAllSyncStates();
}

/// Hive를 사용하여 SyncStateRepository 인터페이스를 구현하는 클래스
class HiveSyncStateRepository implements SyncStateRepository {
  final Box _syncStateBox;

  HiveSyncStateRepository(this._syncStateBox);

  @override
  Future<int> getLastSyncTimestamp(String key) async {
    try {
      // 기본값 0으로 설정
      return Future.value(_syncStateBox.get(key, defaultValue: 0) as int);
    } catch (e) {
      log(
        '[HiveSyncStateRepo] Error getting last sync timestamp for key ($key): $e',
      );
      return 0;
    }
  }

  @override
  Future<void> setLastSyncTimestamp(String key, int timestamp) async {
    try {
      await _syncStateBox.put(key, timestamp);
    } catch (e) {
      log(
        '[HiveSyncStateRepo] Error setting last sync timestamp for key ($key): $e',
      );
      rethrow;
    }
  }

  @override
  Future<void> deleteSyncTimestamp(String key) async {
    try {
      await _syncStateBox.delete(key);
    } catch (e) {
      log(
        '[HiveSyncStateRepo] Error deleting sync timestamp for key ($key): $e',
      );
      rethrow;
    }
  }

  @override
  Future<void> clearAllSyncStates() async {
    await _syncStateBox.clear();
  }
}
