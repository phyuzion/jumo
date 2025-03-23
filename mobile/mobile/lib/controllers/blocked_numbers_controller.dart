import 'dart:developer';

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
    _loadSettings();
    _loadBlockedNumbers(); // 생성자에서 한 번만 로드
  }

  List<BlockedNumber> get blockedNumbers => _blockedNumbers;
  bool get isTodayBlocked => _isTodayBlocked;
  bool get isUnknownBlocked => _isUnknownBlocked;

  void _loadSettings() {
    final box = GetStorage();
    _isTodayBlocked = box.read<bool>('isTodayBlocked') ?? false;
    _isUnknownBlocked = box.read<bool>('isUnknownBlocked') ?? false;

    final todayBlockDate = box.read<String>('todayBlockDate');
    if (todayBlockDate != null) {
      _todayBlockDate = DateTime.parse(todayBlockDate);
    }
  }

  // private 메서드로 변경
  void _loadBlockedNumbers() {
    final List<dynamic> jsonList = GetStorage().read('blocked_numbers') ?? [];
    _blockedNumbers =
        jsonList.map((json) => BlockedNumber.fromJson(json)).toList();
  }

  Future<void> setTodayBlocked(bool value) async {
    _isTodayBlocked = value;
    final box = GetStorage();
    await box.write('isTodayBlocked', value);

    if (value) {
      _todayBlockDate = DateTime.now();
      await box.write('todayBlockDate', _todayBlockDate!.toIso8601String());
    } else {
      _todayBlockDate = null;
      await box.remove('todayBlockDate');
    }
  }

  Future<void> setUnknownBlocked(bool value) async {
    _isUnknownBlocked = value;
    await GetStorage().write('isUnknownBlocked', value);
  }

  Future<void> addBlockedNumber(String number) async {
    try {
      // 현재 메모리의 _blockedNumbers 사용
      _blockedNumbers.add(BlockedNumber(number: number));

      // 서버에 전체 목록 업데이트
      final serverNumbers = await BlockApi.updateBlockedNumbers(
        _blockedNumbers.map((bn) => bn.number).toList(),
      );

      // 로컬 저장소 업데이트
      await _saveBlockedNumbers(
        serverNumbers.map((n) => BlockedNumber(number: n)).toList(),
      );
    } catch (e) {
      // 서버 오류 시에도 현재 메모리의 상태를 저장
      await _saveBlockedNumbers(_blockedNumbers);
      rethrow;
    }
  }

  Future<void> removeBlockedNumber(String number) async {
    try {
      // 현재 메모리의 _blockedNumbers 사용
      _blockedNumbers.removeWhere((bn) => bn.number == number);

      // 서버에 전체 목록 업데이트
      final serverNumbers = await BlockApi.updateBlockedNumbers(
        _blockedNumbers.map((bn) => bn.number).toList(),
      );

      // 로컬 저장소 업데이트
      await _saveBlockedNumbers(
        serverNumbers.map((n) => BlockedNumber(number: n)).toList(),
      );
    } catch (e) {
      // 서버 오류 시에도 현재 메모리의 상태를 저장
      await _saveBlockedNumbers(_blockedNumbers);
      rethrow;
    }
  }

  Future<void> _saveBlockedNumbers(List<BlockedNumber> numbers) async {
    final jsonList = numbers.map((number) => number.toJson()).toList();
    await GetStorage().write('blocked_numbers', jsonList);
    _blockedNumbers = numbers;
  }

  // 번호가 차단되어 있는지 확인
  bool isNumberBlocked(String phoneNumber) {
    // 오늘 상담 차단 체크
    if (_isTodayBlocked && _todayBlockDate != null) {
      final now = DateTime.now();
      final today = DateTime(
        _todayBlockDate!.year,
        _todayBlockDate!.month,
        _todayBlockDate!.day,
      );
      final tomorrow = today.add(const Duration(days: 1));

      if (now.isBefore(tomorrow)) {
        return true;
      } else {
        // 자정이 지났으면 차단 해제
        setTodayBlocked(false);
      }
    }

    // 모르는번호 차단 체크
    if (_isUnknownBlocked) {
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
