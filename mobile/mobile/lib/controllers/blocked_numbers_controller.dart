import 'dart:developer';

import 'package:hive_ce/hive.dart';
import 'package:mobile/graphql/block_api.dart';
import '../models/blocked_number.dart';
import '../models/blocked_history.dart';
import 'package:mobile/controllers/contacts_controller.dart';
import 'package:mobile/graphql/search_api.dart';
import 'package:mobile/utils/constants.dart';

class BlockedNumbersController {
  static const String _blockedHistoryKey = 'blocked_history';
  Box<BlockedHistory> get _historyBox =>
      Hive.box<BlockedHistory>(_blockedHistoryKey);
  Box get _settingsBox => Hive.box('settings');
  Box get _blockedNumbersBox => Hive.box('blocked_numbers');

  final ContactsController _contactsController;
  List<BlockedNumber> _blockedNumbers = [];
  List<BlockedHistory> _blockedHistory = [];
  bool _isInitialized = false;
  List<String> _dangerNumbers = [];
  List<String> _bombCallsNumbers = [];
  bool _isTodayBlocked = false;
  bool _isUnknownBlocked = false;
  bool _isAutoBlockDanger = false;
  bool _isBombCallsBlocked = false;
  int _bombCallsCount = 0;
  DateTime? _todayBlockDate;

  BlockedNumbersController(this._contactsController);

  bool get isInitialized => _isInitialized;
  List<BlockedNumber> get blockedNumbers => _blockedNumbers;
  List<BlockedHistory> get blockedHistory => _blockedHistory;
  List<String> get dangerNumbers => _dangerNumbers;
  List<String> get bombCallsNumbers => _bombCallsNumbers;
  bool get isTodayBlocked => _isTodayBlocked;
  bool get isUnknownBlocked => _isUnknownBlocked;
  bool get isAutoBlockDanger => _isAutoBlockDanger;
  bool get isBombCallsBlocked => _isBombCallsBlocked;
  int get bombCallsCount => _bombCallsCount;

  Future<void> initialize() async {
    if (!_settingsBox.isOpen ||
        !_blockedNumbersBox.isOpen ||
        !_historyBox.isOpen) {
      log('[BlockedNumbers] Required boxes not open during initialize.');
      return;
    }
    try {
      log('[BlockedNumbers] Starting initialization...');

      // 1. 기본 설정 로드
      await _loadSettings();
      log(
        '[BlockedNumbers] Settings loaded: todayBlocked=$_isTodayBlocked, unknownBlocked=$_isUnknownBlocked, autoBlockDanger=$_isAutoBlockDanger, bombCallsBlocked=$_isBombCallsBlocked, bombCallsCount=$_bombCallsCount',
      );

      // 2. 서버 데이터와 동기화
      await _loadBlockedNumbers();
      log(
        '[BlockedNumbers] Blocked numbers loaded: ${_blockedNumbers.length} numbers',
      );

      // 3. 차단 이력 로드
      await _loadBlockedHistory();
      log(
        '[BlockedNumbers] Blocked history loaded: ${_blockedHistory.length} entries',
      );

      // 4. 위험번호 로드 (자동차단이 켜져있을 때만)
      if (_isAutoBlockDanger) {
        await _loadDangerNumbers();
        log(
          '[BlockedNumbers] Danger numbers loaded: ${_dangerNumbers.length} numbers',
        );
      }

      // 5. 콜폭 번호 로드 (콜폭 차단이 켜져있을 때만)
      if (_isBombCallsBlocked && _bombCallsCount > 0) {
        await _loadBombCallsNumbers();
        log(
          '[BlockedNumbers] Bomb calls numbers loaded: ${_bombCallsNumbers.length} numbers',
        );
      }

      _isInitialized = true;
      log('[BlockedNumbers] Initialization completed successfully');
    } catch (e) {
      log('[BlockedNumbers] Error during initialization: $e');
      _isInitialized = false;
    }
  }

  Future<void> _loadSettings() async {
    try {
      _isTodayBlocked = _settingsBox.get('isTodayBlocked', defaultValue: false);
      _isUnknownBlocked = _settingsBox.get(
        'isUnknownBlocked',
        defaultValue: false,
      );
      _isAutoBlockDanger = _settingsBox.get(
        'isAutoBlockDanger',
        defaultValue: false,
      );
      _isBombCallsBlocked = _settingsBox.get(
        'isBombCallsBlocked',
        defaultValue: false,
      );
      _bombCallsCount = _settingsBox.get('bombCallsCount', defaultValue: 0);

      final todayBlockDateStr = _settingsBox.get('todayBlockDate') as String?;
      if (todayBlockDateStr != null) {
        try {
          _todayBlockDate = DateTime.parse(todayBlockDateStr);
        } catch (_) {}
      }
    } catch (e) {
      log('Error loading settings from Hive: $e');
      rethrow;
    }
  }

  Future<void> _loadBlockedNumbers() async {
    try {
      log('[BlockedNumbers] Starting to load blocked numbers...');

      // 서버에서 모든 번호 가져오기
      final serverNumbers = await BlockApi.getBlockedNumbers();
      log(
        '[BlockedNumbers] Server numbers received: ${serverNumbers.length} numbers',
      );

      final numbersToSave =
          serverNumbers.map((n) => normalizePhone(n)).toList();
      await _blockedNumbersBox.clear();
      await _blockedNumbersBox.addAll(numbersToSave);
      _blockedNumbers =
          numbersToSave.map((n) => BlockedNumber(number: n)).toList();

      log('[BlockedNumbers] Blocked numbers updated and saved successfully');
    } catch (e) {
      log('[BlockedNumbers] Error loading/saving blocked numbers: $e');
      final storedNumbers = _blockedNumbersBox.values.toList().cast<String>();
      _blockedNumbers =
          storedNumbers.map((n) => BlockedNumber(number: n)).toList();
      log(
        '[BlockedNumbers] Loaded ${_blockedNumbers.length} numbers from local cache due to error.',
      );
    }
  }

  Future<void> _loadBlockedHistory() async {
    try {
      _blockedHistory = _historyBox.values.toList();
    } catch (e) {
      log('Error loading blocked history from Hive: $e');
      _blockedHistory = [];
    }
  }

  Future<void> _saveBlockedHistory() async {
    try {
      await _historyBox.clear();
      await _historyBox.addAll(_blockedHistory);
    } catch (e) {
      log('Error saving blocked history to Hive: $e');
    }
  }

  Future<void> _addBlockedHistory(String number, String type) async {
    if (!_historyBox.isOpen) {
      log('[BlockedNumbers] History box not open, cannot add history.');
      return;
    }
    final newHistory = BlockedHistory(
      phoneNumber: number,
      blockedAt: DateTime.now(),
      type: type,
    );
    _blockedHistory.add(newHistory);
    try {
      await _historyBox.add(newHistory);
    } catch (e) {
      log('Error adding blocked history to Hive: $e');
    }
  }

  Future<void> setTodayBlocked(bool value) async {
    if (!_settingsBox.isOpen) {
      log('[BlockedNumbers] Settings box not open, cannot set today block.');
      return;
    }
    _isTodayBlocked = value;
    await _settingsBox.put('isTodayBlocked', value);

    if (value) {
      _todayBlockDate = DateTime.now();
      await _settingsBox.put(
        'todayBlockDate',
        _todayBlockDate!.toIso8601String(),
      );
    } else {
      _todayBlockDate = null;
      await _settingsBox.delete('todayBlockDate');
    }
  }

  Future<void> setUnknownBlocked(bool value) async {
    if (!_settingsBox.isOpen) {
      log('[BlockedNumbers] Settings box not open.');
      return;
    }
    _isUnknownBlocked = value;
    await _settingsBox.put('isUnknownBlocked', value);
  }

  Future<void> addBlockedNumber(String number) async {
    if (!_blockedNumbersBox.isOpen) {
      log('[BlockedNumbers] Blocked numbers box not open, cannot add.');
      return;
    }
    final normalizedNumber = normalizePhone(number);
    if (_blockedNumbers.any(
      (bn) => normalizePhone(bn.number) == normalizedNumber,
    )) {
      log('[BlockedNumbers] Number $normalizedNumber already blocked.');
      return;
    }

    _blockedNumbers.add(BlockedNumber(number: normalizedNumber));
    final currentList = _blockedNumbersBox.values.toList().cast<String>();
    if (!currentList.contains(normalizedNumber)) {
      currentList.add(normalizedNumber);
      await _blockedNumbersBox.clear();
      await _blockedNumbersBox.addAll(currentList);
    }

    try {
      log('[BlockedNumbers] Updating server with new blocked list...');
      final serverNumbers = await BlockApi.updateBlockedNumbers(currentList);
      log('[BlockedNumbers] Server update successful.');
    } catch (e) {
      log('[BlockedNumbers] Error updating server blocked numbers: $e');
    }
  }

  Future<void> removeBlockedNumber(String number) async {
    if (!_blockedNumbersBox.isOpen) {
      log('[BlockedNumbers] Blocked numbers box not open, cannot remove.');
      return;
    }
    final normalizedNumber = normalizePhone(number);
    _blockedNumbers.removeWhere(
      (bn) => normalizePhone(bn.number) == normalizedNumber,
    );
    final currentList = _blockedNumbersBox.values.toList().cast<String>();
    if (currentList.remove(normalizedNumber)) {
      await _blockedNumbersBox.clear();
      await _blockedNumbersBox.addAll(currentList);
    }

    try {
      log('[BlockedNumbers] Updating server after removing blocked number...');
      await BlockApi.updateBlockedNumbers(currentList);
      log('[BlockedNumbers] Server update successful after removal.');
    } catch (e) {
      log('[BlockedNumbers] Error updating server after removal: $e');
    }
  }

  Future<void> _loadDangerNumbers() async {
    if (_isAutoBlockDanger) {
      final numbers = await SearchApi.getPhoneNumbersByType(99);
      _dangerNumbers = numbers.map((n) => n.phoneNumber).toList();
    }
  }

  Future<void> _loadBombCallsNumbers() async {
    if (_isBombCallsBlocked && _bombCallsCount > 0) {
      final numbers = await BlockApi.getBlockNumbers(_bombCallsCount);
      _bombCallsNumbers =
          numbers.map((n) => n['phoneNumber'] as String).toList();
    }
  }

  Future<void> setAutoBlockDanger(bool value) async {
    if (!_settingsBox.isOpen) {
      log('[BlockedNumbers] Settings box not open.');
      return;
    }
    _isAutoBlockDanger = value;
    await _settingsBox.put('isAutoBlockDanger', value);
    if (value) {
      await _loadDangerNumbers();
    }
  }

  Future<void> setBombCallsBlocked(bool value) async {
    if (!_settingsBox.isOpen) {
      log('[BlockedNumbers] Settings box not open.');
      return;
    }
    _isBombCallsBlocked = value;
    await _settingsBox.put('isBombCallsBlocked', value);
    if (value) {
      await _loadBombCallsNumbers();
    }
  }

  Future<void> setBombCallsCount(int count) async {
    if (!_settingsBox.isOpen) {
      log('[BlockedNumbers] Settings box not open.');
      return;
    }
    _bombCallsCount = count;
    await _settingsBox.put('bombCallsCount', count);
    if (_isBombCallsBlocked) {
      await _loadBombCallsNumbers();
    }
  }

  Future<bool> isNumberBlockedAsync(
    String phoneNumber, {
    bool addHistory = false,
  }) async {
    const settingsBoxName = 'settings';
    const blockedNumbersBoxName = 'blocked_numbers';
    if (!Hive.isBoxOpen(settingsBoxName) ||
        !Hive.isBoxOpen(blockedNumbersBoxName)) {
      log(
        '[BlockedNumbers] Required boxes not open. Cannot check block status.',
      );
      return false;
    }

    String? blockType;
    final normalizedPhoneNumber = normalizePhone(phoneNumber);

    final isTodayBlockedSetting =
        _settingsBox.get('isTodayBlocked', defaultValue: false) as bool;
    final todayBlockDateStr = _settingsBox.get('todayBlockDate') as String?;
    DateTime? todayBlockDate;
    if (todayBlockDateStr != null) {
      try {
        todayBlockDate = DateTime.parse(todayBlockDateStr);
      } catch (_) {}
    }

    if (isTodayBlockedSetting && todayBlockDate != null) {
      final now = DateTime.now();
      final today = DateTime(
        todayBlockDate.year,
        todayBlockDate.month,
        todayBlockDate.day,
      );
      final tomorrow = today.add(const Duration(days: 1));
      if (now.isBefore(tomorrow)) {
        blockType = 'today';
      } else {
        log('[BlockedNumbers] Today block expired, should be reset.');
      }
    }

    final isUnknownBlockedSetting =
        _settingsBox.get('isUnknownBlocked', defaultValue: false) as bool;
    if (blockType == null && isUnknownBlockedSetting) {
      try {
        final savedContacts = await _contactsController.getLocalContacts();
        if (!savedContacts.any(
          (contact) => contact.phoneNumber == normalizedPhoneNumber,
        )) {
          blockType = 'unknown';
        }
      } catch (e) {
        log('[BlockedNumbers] Error checking unknown number: $e');
      }
    }

    if (blockType == null) {
      final blockedListBox = Hive.box('blocked_numbers');
      if (!blockedListBox.isOpen) {
        log('[BlockedNumbers] blocked_numbers box became closed unexpectedly.');
        return false;
      }
      final blockedList = blockedListBox.values.toList().cast<String>();
      if (blockedList.any(
        (blockedNum) =>
            normalizedPhoneNumber.contains(normalizePhone(blockedNum)),
      )) {
        blockType = 'user';
      }
    }

    if (blockType == null && _isInitialized) {
      final isAutoBlockDangerSetting =
          _settingsBox.get('isAutoBlockDanger', defaultValue: false) as bool;
      if (isAutoBlockDangerSetting &&
          _dangerNumbers.contains(normalizedPhoneNumber)) {
        blockType = 'danger';
      }
      final isBombCallsBlockedSetting =
          _settingsBox.get('isBombCallsBlocked', defaultValue: false) as bool;
      if (blockType == null &&
          isBombCallsBlockedSetting &&
          _bombCallsNumbers.contains(normalizedPhoneNumber)) {
        blockType = 'bomb_calls';
      }
    } else if (blockType == null && !_isInitialized) {
      log(
        '[BlockedNumbers] Controller not initialized, skipping danger/bomb checks.',
      );
    }

    if (blockType != null) {
      if (addHistory) {
        const historyBoxName = 'blocked_history';
        if (Hive.isBoxOpen(historyBoxName)) {
          await _addBlockedHistory(normalizedPhoneNumber, blockType);
        } else {
          log('[BlockedNumbers] History box not open, cannot add history.');
        }
      }
      return true;
    }

    return false;
  }

  @Deprecated('Use isNumberBlockedAsync instead')
  bool isNumberBlocked(String phoneNumber, {bool addHistory = false}) {
    log(
      '[BlockedNumbers] Warning: Synchronous isNumberBlocked called. Returns false.',
    );
    return false;
  }
}
