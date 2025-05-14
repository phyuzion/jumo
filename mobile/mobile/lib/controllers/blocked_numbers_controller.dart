import 'dart:developer';
import 'dart:async';

import 'package:hive_ce/hive.dart';
import 'package:mobile/graphql/block_api.dart';
import '../models/blocked_number.dart';
import '../models/blocked_history.dart';
import 'package:mobile/controllers/contacts_controller.dart';
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

  bool _isInitialized = false;
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
      // 이 함수는 이제 내부 상태를 채우기보다, 필요시 getter를 통해 접근하도록 변경되었으므로 호출 의미가 적음.
      // final numbers = await _blockedNumberRepository.getAllUserBlockedNumbers();
      // log(
      //   '[BlockedNumbers] Loaded ${numbers.length} user blocked numbers from Repo.',
      // );
    } catch (e) {
      log(
        '[BlockedNumbers] Error loading user blocked numbers from Repo (if ever called): $e',
      );
    }
  }

  Future<void> _loadBlockedHistory() async {
    try {
      // 이 함수도 getter를 통해 접근하도록 변경.
      // await _blockedHistoryRepository.getAllBlockedHistory();
      // log('[BlockedNumbers] Blocked history loaded via Repo.');
    } catch (e) {
      log('Error loading blocked history via Repo (if ever called): $e');
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
    log(
      '[BlockedNumbersCtrl][add] Received request to add: $number (normalized: $normalizedNumber)',
    );
    final currentBlocked =
        await _blockedNumberRepository.getAllUserBlockedNumbers();
    if (currentBlocked.contains(normalizedNumber)) {
      log(
        '[BlockedNumbersCtrl][add] Number $normalizedNumber already blocked.',
      );
      return;
    }
    try {
      log('[BlockedNumbersCtrl][add] Calling repository to add number...');
      await _blockedNumberRepository.addUserBlockedNumber(normalizedNumber);
      log('[BlockedNumbersCtrl][add] Repository call finished.');
    } catch (e) {
      log('[BlockedNumbersCtrl][add] Error calling repository: $e');
    }
    log(
      '[BlockedNumbersCtrl][add] Added number $normalizedNumber locally (invoked repo).',
    );
  }

  Future<void> removeBlockedNumber(String number) async {
    final normalizedNumber = normalizePhone(number);
    await _blockedNumberRepository.removeUserBlockedNumber(normalizedNumber);
    log('[BlockedNumbers] Removed number $normalizedNumber locally.');
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
    log(
      '[isNumberBlockedAsync] Checking number: $normalizedPhoneNumber (Original: $phoneNumber)',
    );

    final isTodayBlockedSetting = await _settingsRepository.isTodayBlocked();
    if (isTodayBlockedSetting /* && _isTodayBlockStillValid() */ ) {
      blockType = 'today';
    }

    if (blockType == null) {
      final isUnknownBlockedSetting =
          await _settingsRepository.isUnknownBlocked();
      if (isUnknownBlockedSetting) {
        try {
          final savedContacts = _contactsController.contacts;
          if (!savedContacts.any(
            (contact) =>
                normalizePhone(contact.phoneNumber) == normalizedPhoneNumber,
          )) {
            blockType = 'unknown';
          }
        } catch (e) {
          log(
            '[BlockedNumbers] Error checking unknown number with contacts getter: $e',
          );
        }
      }
    }

    if (blockType == null) {
      final userBlockedList =
          await _blockedNumberRepository.getAllUserBlockedNumbers();
      log(
        '[isNumberBlockedAsync] Checking user block: Normalized incoming = $normalizedPhoneNumber, Blocked List = $userBlockedList',
      );
      if (userBlockedList.any(
        (blockedNum) =>
            normalizedPhoneNumber.contains(normalizePhone(blockedNum)),
      )) {
        blockType = 'user';
        log(
          '[isNumberBlockedAsync] Matched user block list! (incoming contains blocked)',
        );
      }
    }

    if (blockType == null) {
      final isAutoBlockDangerSetting =
          await _settingsRepository.isAutoBlockDanger();
      if (isAutoBlockDangerSetting) {
        final dangerList = await _blockedNumberRepository.getDangerNumbers();
        if (dangerList
            .map((d) => normalizePhone(d))
            .contains(normalizedPhoneNumber)) {
          blockType = 'danger';
        }
      }
      if (blockType == null) {
        final isBombCallsBlockedSetting =
            await _settingsRepository.isBombCallsBlocked();
        if (isBombCallsBlockedSetting) {
          final bombList = await _blockedNumberRepository.getBombNumbers();
          if (bombList
              .map((b) => normalizePhone(b))
              .contains(normalizedPhoneNumber)) {
            blockType = 'bomb_calls';
          }
        }
      }
    }

    if (blockType != null) {
      log(
        '[isNumberBlockedAsync] Final Block Type: $blockType for $normalizedPhoneNumber',
      );
      if (addHistory) {
        await _addBlockedHistory(normalizedPhoneNumber, blockType);
      }
      return true;
    }

    log(
      '[isNumberBlockedAsync] Final Result: $normalizedPhoneNumber NOT BLOCKED',
    );
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
