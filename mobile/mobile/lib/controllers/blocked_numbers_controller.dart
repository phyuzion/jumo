import 'dart:developer';
import 'dart:async';

import 'package:hive_ce/hive.dart';
import 'package:mobile/graphql/block_api.dart';
import '../models/blocked_number.dart';
import '../models/blocked_history.dart';
import 'package:mobile/controllers/contacts_controller.dart';
import 'package:mobile/graphql/search_api.dart';
import 'package:mobile/repositories/settings_repository.dart';
import 'package:mobile/repositories/blocked_number_repository.dart';
import 'package:mobile/utils/constants.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:mobile/repositories/blocked_history_repository.dart';

class BlockedNumbersController {
  final ContactsController _contactsController;
  final SettingsRepository _settingsRepository;
  final BlockedNumberRepository _blockedNumberRepository;
  final BlockedHistoryRepository _blockedHistoryRepository;

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

  BlockedNumbersController(
    this._contactsController,
    this._settingsRepository,
    this._blockedNumberRepository,
    this._blockedHistoryRepository,
  );

  bool get isInitialized => _isInitialized;
  Future<List<BlockedNumber>> get blockedNumbers async {
    final numbers = await _blockedNumberRepository.getAllUserBlockedNumbers();
    return numbers.map((n) => BlockedNumber(number: n)).toList();
  }

  Future<List<BlockedHistory>> get blockedHistory async =>
      await _blockedHistoryRepository.getAllBlockedHistory();
  Future<List<String>> get dangerNumbers async =>
      await _blockedNumberRepository.getDangerNumbers();
  Future<List<String>> get bombCallsNumbers async =>
      await _blockedNumberRepository.getBombNumbers();
  bool get isTodayBlocked => _isTodayBlocked;
  bool get isUnknownBlocked => _isUnknownBlocked;
  bool get isAutoBlockDanger => _isAutoBlockDanger;
  bool get isBombCallsBlocked => _isBombCallsBlocked;
  int get bombCallsCount => _bombCallsCount;

  Future<void> initialize() async {
    final stopwatch = Stopwatch()..start();
    log(
      '[BlockedNumbers] Initialization started (loading from local cache & repo)...',
    );
    try {
      final stepWatch = Stopwatch();

      stepWatch.start();
      await Future.wait([
        _loadSettings(),
        _loadUserBlockedNumbers(),
        _loadBlockedHistory(),
      ]);
      log(
        '[BlockedNumbers] Initial data load took: ${stepWatch.elapsedMilliseconds}ms',
      );
      stepWatch.reset();

      log('[BlockedNumbers] Danger/Bomb number loading deferred.');

      _isInitialized = true;
      log(
        '[BlockedNumbers] Initialization completed successfully (local data only)',
      );
    } catch (e) {
      log('[BlockedNumbers] Error during initialization: $e');
      _isInitialized = false;
    } finally {
      stopwatch.stop();
      log(
        '[BlockedNumbers] Total initialize (local only) took: ${stopwatch.elapsedMilliseconds}ms',
      );
    }
  }

  Future<void> _loadSettings() async {
    try {
      _isTodayBlocked = await _settingsRepository.isTodayBlocked();
      _isUnknownBlocked = await _settingsRepository.isUnknownBlocked();
      _isAutoBlockDanger = await _settingsRepository.isAutoBlockDanger();
      _isBombCallsBlocked = await _settingsRepository.isBombCallsBlocked();
      _bombCallsCount = await _settingsRepository.getBombCallsCount();
    } catch (e) {
      log('Error loading settings via Repository: $e');
      rethrow;
    }
  }

  Future<void> _loadUserBlockedNumbers() async {
    try {
      final numbers = await _blockedNumberRepository.getAllUserBlockedNumbers();
      log(
        '[BlockedNumbers] Loaded ${numbers.length} user blocked numbers from Repo.',
      );
    } catch (e) {
      log('[BlockedNumbers] Error loading user blocked numbers from Repo: $e');
    }
  }

  Future<void> _loadBlockedHistory() async {
    try {
      await _blockedHistoryRepository.getAllBlockedHistory();
      log('[BlockedNumbers] Blocked history loaded via Repo.');
    } catch (e) {
      log('Error loading blocked history via Repo: $e');
    }
  }

  Future<void> _addBlockedHistory(String number, String type) async {
    final newHistory = BlockedHistory(
      phoneNumber: number,
      blockedAt: DateTime.now(),
      type: type,
    );
    await _blockedHistoryRepository.addBlockedHistory(newHistory);
  }

  Future<void> setTodayBlocked(bool value) async {
    _isTodayBlocked = value;
    await _settingsRepository.setTodayBlocked(value);
  }

  Future<void> setUnknownBlocked(bool value) async {
    _isUnknownBlocked = value;
    await _settingsRepository.setUnknownBlocked(value);
  }

  Future<void> addBlockedNumber(String number) async {
    final normalizedNumber = normalizePhone(number);
    final currentBlocked =
        await _blockedNumberRepository.getAllUserBlockedNumbers();
    if (currentBlocked.contains(normalizedNumber)) {
      log('[BlockedNumbers] Number $normalizedNumber already blocked.');
      return;
    }
    await _blockedNumberRepository.addUserBlockedNumber(normalizedNumber);
    log('[BlockedNumbers] Requesting background sync after adding number...');
    FlutterBackgroundService().invoke('syncBlockedListsNow');
  }

  Future<void> removeBlockedNumber(String number) async {
    final normalizedNumber = normalizePhone(number);
    await _blockedNumberRepository.removeUserBlockedNumber(normalizedNumber);
    log('[BlockedNumbers] Requesting background sync after removing number...');
    FlutterBackgroundService().invoke('syncBlockedListsNow');
  }

  Future<void> setAutoBlockDanger(bool value) async {
    _isAutoBlockDanger = value;
    await _settingsRepository.setAutoBlockDanger(value);
    log(
      '[BlockedNumbers] Requesting background sync after setting AutoBlockDanger...',
    );
    FlutterBackgroundService().invoke('syncBlockedListsNow');
  }

  Future<void> setBombCallsBlocked(bool value) async {
    _isBombCallsBlocked = value;
    await _settingsRepository.setBombCallsBlocked(value);
    log(
      '[BlockedNumbers] Requesting background sync after setting BombCallsBlocked...',
    );
    FlutterBackgroundService().invoke('syncBlockedListsNow');
  }

  Future<void> setBombCallsCount(int count) async {
    _bombCallsCount = count;
    await _settingsRepository.setBombCallsCount(count);
    log(
      '[BlockedNumbers] Requesting background sync after setting BombCallsCount...',
    );
    FlutterBackgroundService().invoke('syncBlockedListsNow');
  }

  Future<bool> isNumberBlockedAsync(
    String phoneNumber, {
    bool addHistory = false,
  }) async {
    String? blockType;
    final normalizedPhoneNumber = normalizePhone(phoneNumber);

    final isTodayBlockedSetting = await _settingsRepository.isTodayBlocked();
    if (isTodayBlockedSetting /* && _isTodayBlockStillValid() */ ) {
      blockType = 'today';
    }

    if (blockType == null) {
      final isUnknownBlockedSetting =
          await _settingsRepository.isUnknownBlocked();
      if (isUnknownBlockedSetting) {
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
    }

    if (blockType == null) {
      final userBlockedList =
          await _blockedNumberRepository.getAllUserBlockedNumbers();
      if (userBlockedList.contains(normalizedPhoneNumber)) {
        blockType = 'user';
      }
    }

    if (blockType == null) {
      final isAutoBlockDangerSetting =
          await _settingsRepository.isAutoBlockDanger();
      if (isAutoBlockDangerSetting) {
        final dangerList = await _blockedNumberRepository.getDangerNumbers();
        if (dangerList.contains(normalizedPhoneNumber)) {
          blockType = 'danger';
        }
      }
      if (blockType == null) {
        final isBombCallsBlockedSetting =
            await _settingsRepository.isBombCallsBlocked();
        if (isBombCallsBlockedSetting) {
          final bombList = await _blockedNumberRepository.getBombNumbers();
          if (bombList.contains(normalizedPhoneNumber)) {
            blockType = 'bomb_calls';
          }
        }
      }
    }

    if (blockType != null) {
      if (addHistory) {
        await _addBlockedHistory(normalizedPhoneNumber, blockType);
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
