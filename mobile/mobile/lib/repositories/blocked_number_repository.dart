import 'dart:convert';
import 'dart:developer';
import 'package:hive_ce/hive.dart';

// Hive 박스 이름 정의
const String _blockedNumbersBoxName = 'blocked_numbers';
const String _dangerNumbersBoxName = 'danger_numbers';
const String _bombNumbersBoxName = 'bomb_numbers';

/// 차단 번호 관련 데이터 접근을 위한 추상 클래스 (인터페이스)
abstract class BlockedNumberRepository {
  // --- 사용자 직접 차단 목록 --- ('blocked_numbers' box)
  Future<List<String>> getAllUserBlockedNumbers();
  Future<void> saveAllUserBlockedNumbers(List<String> numbers);
  Future<void> addUserBlockedNumber(String number);
  Future<void> removeUserBlockedNumber(String number);

  // --- 위험 번호 목록 --- ('danger_numbers' box, 'list' key)
  Future<List<String>> getDangerNumbers();
  Future<void> saveDangerNumbers(List<String> numbers);
  Future<void> clearDangerNumbers();

  // --- 콜폭 번호 목록 --- ('bomb_numbers' box, 'list' key)
  Future<List<String>> getBombNumbers();
  Future<void> saveBombNumbers(List<String> numbers);
  Future<void> clearBombNumbers();

  /// 모든 차단 관련 데이터 삭제 (로그아웃 등)
  Future<void> clearAllBlockedNumberData();
}

/// Hive를 사용하여 BlockedNumberRepository 인터페이스를 구현하는 클래스
class HiveBlockedNumberRepository implements BlockedNumberRepository {
  final Box _blockedNumbersBox;
  final Box<List<String>> _dangerNumbersBox; // 타입 명시
  final Box<List<String>> _bombNumbersBox; // 타입 명시

  HiveBlockedNumberRepository(
    this._blockedNumbersBox,
    this._dangerNumbersBox,
    this._bombNumbersBox,
  );

  // --- 사용자 직접 차단 목록 구현 ---
  @override
  Future<List<String>> getAllUserBlockedNumbers() async {
    try {
      // Box의 values가 String 리스트인지 확인 후 반환
      final numbers = _blockedNumbersBox.values.toList();
      return numbers.map((e) => e.toString()).toList(); // 안전하게 String으로 변환
    } catch (e) {
      log('[HiveBlockedNumberRepo] Error getting user blocked numbers: $e');
      return [];
    }
  }

  @override
  Future<void> saveAllUserBlockedNumbers(List<String> numbers) async {
    try {
      await _blockedNumbersBox.clear();
      await _blockedNumbersBox.addAll(numbers);
    } catch (e) {
      log('[HiveBlockedNumberRepo] Error saving user blocked numbers: $e');
      rethrow;
    }
  }

  @override
  Future<void> addUserBlockedNumber(String number) async {
    log('[HiveBlockedNumberRepo][addUser] Attempting to add number: $number');
    try {
      log(
        '[HiveBlockedNumberRepo][addUser] Box state BEFORE add: ${_blockedNumbersBox.values.toList()}',
      );

      if (!_blockedNumbersBox.values.contains(number)) {
        await _blockedNumbersBox.add(number);
        log(
          '[HiveBlockedNumberRepo][addUser] Successfully added number: $number',
        );
      } else {
        log(
          '[HiveBlockedNumberRepo][addUser] Number $number already exists, not adding again.',
        );
      }
      log(
        '[HiveBlockedNumberRepo][addUser] Box state AFTER add: ${_blockedNumbersBox.values.toList()}',
      );
    } catch (e) {
      log(
        '[HiveBlockedNumberRepo][addUser] Error adding user blocked number: $e',
      );
      rethrow;
    }
  }

  @override
  Future<void> removeUserBlockedNumber(String number) async {
    try {
      // Box에서 해당 값을 찾아 key를 얻은 후 삭제
      dynamic keyToRemove;
      for (var entry in _blockedNumbersBox.toMap().entries) {
        if (entry.value == number) {
          keyToRemove = entry.key;
          break;
        }
      }
      if (keyToRemove != null) {
        await _blockedNumbersBox.delete(keyToRemove);
      }
    } catch (e) {
      log('[HiveBlockedNumberRepo] Error removing user blocked number: $e');
      rethrow;
    }
  }

  // --- 위험 번호 목록 구현 ---
  @override
  Future<List<String>> getDangerNumbers() async {
    try {
      return List<String>.from(
        _dangerNumbersBox.get('list', defaultValue: []) ?? [],
      );
    } catch (e) {
      log('[HiveBlockedNumberRepo] Error getting danger numbers: $e');
      return [];
    }
  }

  @override
  Future<void> saveDangerNumbers(List<String> numbers) async {
    try {
      await _dangerNumbersBox.put('list', numbers);
    } catch (e) {
      log('[HiveBlockedNumberRepo] Error saving danger numbers: $e');
      rethrow;
    }
  }

  @override
  Future<void> clearDangerNumbers() async {
    try {
      await _dangerNumbersBox.delete('list');
    } catch (e) {
      log('[HiveBlockedNumberRepo] Error clearing danger numbers: $e');
      rethrow;
    }
  }

  // --- 콜폭 번호 목록 구현 ---
  @override
  Future<List<String>> getBombNumbers() async {
    try {
      return List<String>.from(
        _bombNumbersBox.get('list', defaultValue: []) ?? [],
      );
    } catch (e) {
      log('[HiveBlockedNumberRepo] Error getting bomb numbers: $e');
      return [];
    }
  }

  @override
  Future<void> saveBombNumbers(List<String> numbers) async {
    try {
      await _bombNumbersBox.put('list', numbers);
    } catch (e) {
      log('[HiveBlockedNumberRepo] Error saving bomb numbers: $e');
      rethrow;
    }
  }

  @override
  Future<void> clearBombNumbers() async {
    try {
      await _bombNumbersBox.delete('list');
    } catch (e) {
      log('[HiveBlockedNumberRepo] Error clearing bomb numbers: $e');
      rethrow;
    }
  }

  // --- 모든 데이터 삭제 구현 ---
  @override
  Future<void> clearAllBlockedNumberData() async {
    await _blockedNumbersBox.clear();
    await _dangerNumbersBox.clear();
    await _bombNumbersBox.clear();
  }
}
