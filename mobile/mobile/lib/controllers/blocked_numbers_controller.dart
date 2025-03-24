import 'dart:developer';

import 'package:get_storage/get_storage.dart';
import 'package:mobile/graphql/block_api.dart';
import '../models/blocked_number.dart';
import '../models/blocked_history.dart';
import 'package:mobile/controllers/contacts_controller.dart';
import 'package:mobile/graphql/search_api.dart';

class BlockedNumbersController {
  static const String _blockedHistoryKey = 'blocked_history';
  final _storage = GetStorage();
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

      log('[BlockedNumbers] Initialization completed successfully');
    } catch (e) {
      log('[BlockedNumbers] Error during initialization: $e');
      rethrow;
    }
  }

  Future<void> _loadSettings() async {
    try {
      _isTodayBlocked = _storage.read<bool>('isTodayBlocked') ?? false;
      _isUnknownBlocked = _storage.read<bool>('isUnknownBlocked') ?? false;
      _isAutoBlockDanger = _storage.read<bool>('isAutoBlockDanger') ?? false;
      _isBombCallsBlocked = _storage.read<bool>('isBombCallsBlocked') ?? false;
      _bombCallsCount = _storage.read<int>('bombCallsCount') ?? 0;

      final todayBlockDate = _storage.read<String>('todayBlockDate');
      if (todayBlockDate != null) {
        _todayBlockDate = DateTime.parse(todayBlockDate);
      }
    } catch (e) {
      log('Error loading settings: $e');
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

      // 로컬 저장소에 저장
      final updatedNumbers =
          serverNumbers.map((n) => BlockedNumber(number: n)).toList();
      await _saveBlockedNumbers(updatedNumbers);
      log('[BlockedNumbers] Numbers updated and saved successfully');
    } catch (e) {
      log('[BlockedNumbers] Error loading blocked numbers: $e');
      rethrow;
    }
  }

  Future<void> _loadBlockedHistory() async {
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
    await _storage.write('isTodayBlocked', value);

    if (value) {
      _todayBlockDate = DateTime.now();
      await _storage.write(
        'todayBlockDate',
        _todayBlockDate!.toIso8601String(),
      );
    } else {
      _todayBlockDate = null;
      await _storage.remove('todayBlockDate');
    }
  }

  Future<void> setUnknownBlocked(bool value) async {
    _isUnknownBlocked = value;
    await _storage.write('isUnknownBlocked', value);
  }

  Future<void> addBlockedNumber(String number) async {
    try {
      log('[BlockedNumbers] Adding blocked number: $number');
      _blockedNumbers.add(BlockedNumber(number: number));
      log(
        '[BlockedNumbers] Current blocked numbers: ${_blockedNumbers.length} numbers',
      );

      final serverNumbers = await BlockApi.updateBlockedNumbers(
        _blockedNumbers.map((bn) => bn.number).toList(),
      );
      log(
        '[BlockedNumbers] Server update response: ${serverNumbers.length} numbers',
      );

      await _saveBlockedNumbers(
        serverNumbers.map((n) => BlockedNumber(number: n)).toList(),
      );
      log('[BlockedNumbers] Number added and saved successfully');
    } catch (e) {
      log('[BlockedNumbers] Error adding blocked number: $e');
      await _saveBlockedNumbers(_blockedNumbers);
      rethrow;
    }
  }

  Future<void> removeBlockedNumber(String number) async {
    try {
      log('[BlockedNumbers] Removing blocked number: $number');
      _blockedNumbers.removeWhere((bn) => bn.number == number);
      log(
        '[BlockedNumbers] Current blocked numbers: ${_blockedNumbers.length} numbers',
      );

      final serverNumbers = await BlockApi.updateBlockedNumbers(
        _blockedNumbers.map((bn) => bn.number).toList(),
      );
      log(
        '[BlockedNumbers] Server update response: ${serverNumbers.length} numbers',
      );

      await _saveBlockedNumbers(
        serverNumbers.map((n) => BlockedNumber(number: n)).toList(),
      );
      log('[BlockedNumbers] Number removed and saved successfully');
    } catch (e) {
      log('[BlockedNumbers] Error removing blocked number: $e');
      await _saveBlockedNumbers(_blockedNumbers);
      rethrow;
    }
  }

  Future<void> _saveBlockedNumbers(List<BlockedNumber> numbers) async {
    try {
      log('[BlockedNumbers] Saving blocked numbers...');
      final jsonList = numbers.map((number) => number.toJson()).toList();
      await _storage.write('blocked_numbers', jsonList);
      _blockedNumbers = numbers;
      log(
        '[BlockedNumbers] Numbers saved successfully: ${_blockedNumbers.length} numbers',
      );
    } catch (e) {
      log('[BlockedNumbers] Error saving blocked numbers: $e');
      rethrow;
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
    _isAutoBlockDanger = value;
    await _storage.write('isAutoBlockDanger', value);
    if (value) {
      await _loadDangerNumbers();
    }
  }

  Future<void> setBombCallsBlocked(bool value) async {
    _isBombCallsBlocked = value;
    await _storage.write('isBombCallsBlocked', value);
    if (value) {
      await _loadBombCallsNumbers();
    }
  }

  Future<void> setBombCallsCount(int count) async {
    _bombCallsCount = count;
    await _storage.write('bombCallsCount', count);
    if (_isBombCallsBlocked) {
      await _loadBombCallsNumbers();
    }
  }

  bool isNumberBlocked(String phoneNumber) {
    String? blockType;

    // 위험번호 자동 차단 체크
    if (_isAutoBlockDanger && _dangerNumbers.contains(phoneNumber)) {
      blockType = 'danger';
    }
    // 통화 횟수 기반 차단 체크
    else if (_isBombCallsBlocked && _bombCallsNumbers.contains(phoneNumber)) {
      blockType = 'bomb_calls';
    }
    // 오늘 상담 차단 체크
    else if (_isTodayBlocked && _todayBlockDate != null) {
      final now = DateTime.now();
      final today = DateTime(
        _todayBlockDate!.year,
        _todayBlockDate!.month,
        _todayBlockDate!.day,
      );
      final tomorrow = today.add(const Duration(days: 1));

      if (now.isBefore(tomorrow)) {
        blockType = 'today';
      } else {
        setTodayBlocked(false);
      }
    }
    // 모르는번호 차단 체크
    else if (_isUnknownBlocked) {
      final savedContacts = _contactsController.getSavedContacts();
      if (!savedContacts.any((contact) => contact.phoneNumber == phoneNumber)) {
        blockType = 'unknown';
      }
    }
    // 사용자가 추가한 번호 체크 (포함)
    else if (_blockedNumbers.any(
      (blocked) => phoneNumber.contains(blocked.number),
    )) {
      blockType = 'user';
    }

    if (blockType != null) {
      _addBlockedHistory(phoneNumber, blockType);
      return true;
    }

    return false;
  }
}
