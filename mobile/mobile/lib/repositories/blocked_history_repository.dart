import 'dart:developer';
import 'package:hive_ce/hive.dart';
import 'package:mobile/models/blocked_history.dart'; // BlockedHistory 모델 임포트

// Hive 박스 이름 정의
const String _blockedHistoryBoxName = 'blocked_history';

/// 차단 이력 데이터 접근을 위한 추상 클래스 (인터페이스)
abstract class BlockedHistoryRepository {
  /// 저장된 모든 차단 이력 목록을 가져옵니다.
  Future<List<BlockedHistory>> getAllBlockedHistory();

  /// 새로운 차단 이력을 추가합니다.
  Future<void> addBlockedHistory(BlockedHistory history);

  /// 모든 차단 이력 데이터를 삭제합니다 (로그아웃 등에서 사용).
  Future<void> clearBlockedHistory();
}

/// Hive를 사용하여 BlockedHistoryRepository 인터페이스를 구현하는 클래스
class HiveBlockedHistoryRepository implements BlockedHistoryRepository {
  final Box<BlockedHistory> _blockedHistoryBox;

  HiveBlockedHistoryRepository(this._blockedHistoryBox);

  @override
  Future<List<BlockedHistory>> getAllBlockedHistory() async {
    try {
      // Box<BlockedHistory> 이므로 values는 이미 List<BlockedHistory> 타입
      return _blockedHistoryBox.values.toList();
    } catch (e) {
      log('[HiveBlockedHistoryRepo] Error getting all blocked history: $e');
      return [];
    }
  }

  @override
  Future<void> addBlockedHistory(BlockedHistory history) async {
    try {
      // Box<T>의 add는 List처럼 동작하여 value를 추가
      await _blockedHistoryBox.add(history);
    } catch (e) {
      log('[HiveBlockedHistoryRepo] Error adding blocked history: $e');
      rethrow;
    }
  }

  @override
  Future<void> clearBlockedHistory() async {
    await _blockedHistoryBox.clear();
  }
}
