import 'dart:developer';

import 'package:get_storage/get_storage.dart';
import 'package:mobile/graphql/block_api.dart';
import '../models/blocked_number.dart';
import '../models/blocked_history.dart';
import 'package:flutter/material.dart';
import 'package:mobile/controllers/contacts_controller.dart';

class BlockedNumbersController {
  static const String _blockedHistoryKey = 'blocked_history';
  final _storage = GetStorage();
  final ContactsController _contactsController;
  List<BlockedNumber> _blockedNumbers = [];
  List<BlockedHistory> _blockedHistory = [];
  bool _isTodayBlocked = false;
  bool _isUnknownBlocked = false;
  DateTime? _todayBlockDate;

  BlockedNumbersController(this._contactsController) {
    _loadSettings();
    _loadBlockedNumbers();
    _loadBlockedHistory();
  }

  List<BlockedNumber> get blockedNumbers => _blockedNumbers;
  List<BlockedHistory> get blockedHistory => _blockedHistory;
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

  void _loadBlockedNumbers() {
    final List<dynamic> jsonList = GetStorage().read('blocked_numbers') ?? [];
    _blockedNumbers =
        jsonList.map((json) => BlockedNumber.fromJson(json)).toList();
  }

  void _loadBlockedHistory() {
    final List<dynamic> jsonList = _storage.read(_blockedHistoryKey) ?? [];
    _blockedHistory =
        jsonList.map((json) => BlockedHistory.fromJson(json)).toList();
  }

  Future<void> _saveBlockedHistory() async {
    final jsonList =
        _blockedHistory.map((history) => history.toJson()).toList();
    await _storage.write(_blockedHistoryKey, jsonList);
  }

  Future<void> _addBlockedHistory(String number, String type) async {
    _blockedHistory.add(
      BlockedHistory(
        phoneNumber: number,
        blockedAt: DateTime.now(),
        type: type,
      ),
    );
    await _saveBlockedHistory();
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
      _blockedNumbers.add(BlockedNumber(number: number));
      final serverNumbers = await BlockApi.updateBlockedNumbers(
        _blockedNumbers.map((bn) => bn.number).toList(),
      );
      await _saveBlockedNumbers(
        serverNumbers.map((n) => BlockedNumber(number: n)).toList(),
      );
    } catch (e) {
      await _saveBlockedNumbers(_blockedNumbers);
      rethrow;
    }
  }

  Future<void> removeBlockedNumber(String number) async {
    try {
      _blockedNumbers.removeWhere((bn) => bn.number == number);
      final serverNumbers = await BlockApi.updateBlockedNumbers(
        _blockedNumbers.map((bn) => bn.number).toList(),
      );
      await _saveBlockedNumbers(
        serverNumbers.map((n) => BlockedNumber(number: n)).toList(),
      );
    } catch (e) {
      await _saveBlockedNumbers(_blockedNumbers);
      rethrow;
    }
  }

  Future<void> _saveBlockedNumbers(List<BlockedNumber> numbers) async {
    final jsonList = numbers.map((number) => number.toJson()).toList();
    await GetStorage().write('blocked_numbers', jsonList);
    _blockedNumbers = numbers;
  }

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
        _addBlockedHistory(phoneNumber, 'today');
        return true;
      } else {
        setTodayBlocked(false);
      }
    }

    // 모르는번호 차단 체크
    if (_isUnknownBlocked) {
      final savedContacts = _contactsController.getSavedContacts();
      if (!savedContacts.any((contact) => contact.phoneNumber == phoneNumber)) {
        _addBlockedHistory(phoneNumber, 'unknown');
        return true;
      }
    }

    // 사용자가 추가한 번호 체크 (포함)
    if (_blockedNumbers.any(
      (blocked) => phoneNumber.contains(blocked.number),
    )) {
      _addBlockedHistory(phoneNumber, 'user');
      return true;
    }

    return false;
  }
}
