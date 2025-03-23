import 'package:get_storage/get_storage.dart';
import 'package:mobile/graphql/block_api.dart';
import '../models/blocked_number.dart';
import 'package:flutter/material.dart';
import 'package:mobile/controllers/contacts_controller.dart';

class BlockedNumbersController {
  final ContactsController _contactsController;
  List<BlockedNumber> _blockedNumbers = [];
  bool _isTodayBlocked = false;
  bool _isUnknownBlocked = false;
  DateTime? _todayBlockDate;

  BlockedNumbersController(this._contactsController) {
    loadUserBlockedNumbers();
  }

  List<BlockedNumber> get blockedNumbers => _blockedNumbers;
  bool get isTodayBlocked => _isTodayBlocked;
  bool get isUnknownBlocked => _isUnknownBlocked;

  List<BlockedNumber> getBlockedNumbers() {
    final List<dynamic> jsonList = GetStorage().read('blocked_numbers') ?? [];
    return jsonList.map((json) => BlockedNumber.fromJson(json)).toList();
  }

  Future<void> addBlockedNumber(String number) async {
    try {
      final blockedNumbers = getBlockedNumbers();
      blockedNumbers.add(BlockedNumber(number: number));

      // 서버에 전체 목록 업데이트
      final serverNumbers = await BlockApi.updateBlockedNumbers(
        blockedNumbers.map((bn) => bn.number).toList(),
      );

      // 로컬 저장소 업데이트
      await _saveBlockedNumbers(
        serverNumbers.map((n) => BlockedNumber(number: n)).toList(),
      );
    } catch (e) {
      // 서버 오류 시 로컬에만 저장
      final blockedNumbers = getBlockedNumbers();
      blockedNumbers.add(BlockedNumber(number: number));
      await _saveBlockedNumbers(blockedNumbers);
      rethrow;
    }
  }

  Future<void> removeBlockedNumber(String number) async {
    try {
      final blockedNumbers = getBlockedNumbers();
      blockedNumbers.removeWhere((blocked) => blocked.number == number);

      // 서버에 전체 목록 업데이트
      final serverNumbers = await BlockApi.updateBlockedNumbers(
        blockedNumbers.map((bn) => bn.number).toList(),
      );

      // 로컬 저장소 업데이트
      await _saveBlockedNumbers(
        serverNumbers.map((n) => BlockedNumber(number: n)).toList(),
      );
    } catch (e) {
      // 서버 오류 시 로컬에서만 제거
      final blockedNumbers = getBlockedNumbers();
      blockedNumbers.removeWhere((blocked) => blocked.number == number);
      await _saveBlockedNumbers(blockedNumbers);
      rethrow;
    }
  }

  Future<void> _saveBlockedNumbers(List<BlockedNumber> numbers) async {
    final jsonList = numbers.map((number) => number.toJson()).toList();
    GetStorage().write('blocked_numbers', jsonList);
  }

  void loadUserBlockedNumbers() {
    _blockedNumbers = getBlockedNumbers();
  }

  // 오늘 상담 차단 설정
  Future<void> setTodayBlocked(bool value) async {
    _isTodayBlocked = value;
    if (value) {
      _todayBlockDate = DateTime.now();
    } else {
      _todayBlockDate = null;
    }
  }

  // 모르는번호 차단 설정
  Future<void> setUnknownBlocked(bool value) async {
    _isUnknownBlocked = value;
  }

  // 번호가 차단되어 있는지 확인
  bool isNumberBlocked(String phoneNumber) {
    final box = GetStorage();

    // 오늘 상담 차단 체크
    if (box.read<bool>('isTodayBlocked') == true) {
      final todayBlockDate = box.read<String>('todayBlockDate');
      if (todayBlockDate != null) {
        final blockDate = DateTime.parse(todayBlockDate);
        final now = DateTime.now();
        final today = DateTime(blockDate.year, blockDate.month, blockDate.day);
        final tomorrow = today.add(const Duration(days: 1));

        if (now.isBefore(tomorrow)) {
          return true;
        } else {
          // 자정이 지났으면 차단 해제
          box.write('isTodayBlocked', false);
          box.remove('todayBlockDate');
        }
      }
    }

    // 모르는번호 차단 체크
    if (box.read<bool>('isUnknownBlocked') == true) {
      final savedContacts = _contactsController.getSavedContacts();
      if (!savedContacts.any((contact) => contact.phoneNumber == phoneNumber)) {
        return true;
      }
    }

    // 사용자가 추가한 번호 체크 (포함)
    return _blockedNumbers.any(
      (blocked) => phoneNumber.contains(blocked.number),
    );
  }
}
