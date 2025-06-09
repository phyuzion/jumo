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

      // 백그라운드 서비스에 변경 사항 즉시 알림
      log('[BlockedNumbersCtrl][add] 사용자 차단 번호 추가 후 서버 동기화 요청');
      FlutterBackgroundService().invoke('syncBlockedListsNow');

      // 사용자 차단 번호 직접 업데이트 요청
      log('[BlockedNumbersCtrl][add] 사용자 차단 번호 직접 업데이트 요청');
      final allNumbers =
          await _blockedNumberRepository.getAllUserBlockedNumbers();
      FlutterBackgroundService().invoke('updateUserBlockedNumbers', {
        'numbers': allNumbers,
      });
    } catch (e) {
      log('[BlockedNumbersCtrl][add] Error calling repository: $e');
    }
    log(
      '[BlockedNumbersCtrl][add] Added number $normalizedNumber locally (invoked repo).',
    );
  }

  Future<void> removeBlockedNumber(String number) async {
    final normalizedNumber = normalizePhone(number);
    log('[BlockedNumbersCtrl][remove] 차단 번호 제거 요청: $normalizedNumber');

    try {
      await _blockedNumberRepository.removeUserBlockedNumber(normalizedNumber);
      log('[BlockedNumbersCtrl][remove] 저장소에서 번호 제거 완료');

      // 백그라운드 서비스에 변경 사항 즉시 알림
      log('[BlockedNumbersCtrl][remove] 사용자 차단 번호 제거 후 서버 동기화 요청');
      FlutterBackgroundService().invoke('syncBlockedListsNow');

      // 사용자 차단 번호 직접 업데이트 요청
      log('[BlockedNumbersCtrl][remove] 사용자 차단 번호 직접 업데이트 요청');
      final allNumbers =
          await _blockedNumberRepository.getAllUserBlockedNumbers();
      FlutterBackgroundService().invoke('updateUserBlockedNumbers', {
        'numbers': allNumbers,
      });
    } catch (e) {
      log('[BlockedNumbersCtrl][remove] 차단 번호 제거 오류: $e');
    }
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
    log('[BlockedNumbers] 콜폭 차단 횟수 변경: $_bombCallsCount → $count');
    _bombCallsCount = count;
    await _settingsRepository.setBombCallsCount(count);
    log('[BlockedNumbers] 콜폭 차단 횟수 설정 저장 완료, 백그라운드 서비스에 동기화 요청');
    FlutterBackgroundService().invoke('syncBlockedListsNow');

    // 콜폭 번호를 직접 요청하는 이벤트도 추가 발송
    log('[BlockedNumbers] 콜폭 번호 직접 요청: count=$count');
    FlutterBackgroundService().invoke('requestBombNumbers', {'count': count});
  }

  Future<bool> isNumberBlockedAsync(
    String phoneNumber, {
    bool addHistory = false,
  }) async {
    final normalizedPhoneNumber = normalizePhone(phoneNumber);

    // 각 차단 유형별로 검사
    final blockType = await _getBlockTypeForNumber(normalizedPhoneNumber);

    if (blockType != null) {
      if (addHistory) {
        await _addBlockedHistory(normalizedPhoneNumber, blockType);
      }
      return true;
    }

    return false;
  }

  /// 특정 번호의 차단 유형을 확인
  ///
  /// @return 차단된 경우 차단 유형 문자열 ('today', 'unknown', 'user', 'danger', 'bomb_calls'), 차단되지 않은 경우 null
  Future<String?> _getBlockTypeForNumber(String normalizedPhoneNumber) async {
    // 1. 오늘 전화 차단 확인
    if (await isTodayBlockedAsync(normalizedPhoneNumber)) {
      return 'today';
    }

    // 2. 저장 안된 번호 차단 확인
    if (await isUnknownBlockedAsync(normalizedPhoneNumber)) {
      return 'unknown';
    }

    // 3. 사용자 지정 차단 확인
    if (await isUserBlockedAsync(normalizedPhoneNumber)) {
      return 'user';
    }

    // 4. 위험 번호 차단 확인
    if (await isDangerBlockedAsync(normalizedPhoneNumber)) {
      return 'danger';
    }

    // 5. 콜폭 번호 차단 확인
    if (await isBombCallBlockedAsync(normalizedPhoneNumber)) {
      return 'bomb_calls';
    }

    return null;
  }

  /// 오늘 전화 차단 설정에 따라 차단 여부 확인
  Future<bool> isTodayBlockedAsync(String normalizedPhoneNumber) async {
    final isTodayBlockedSetting = await _settingsRepository.isTodayBlocked();
    return isTodayBlockedSetting /* && _isTodayBlockStillValid() */;
  }

  /// 저장 안된 번호 차단 설정에 따라 차단 여부 확인
  Future<bool> isUnknownBlockedAsync(String normalizedPhoneNumber) async {
    final isUnknownBlockedSetting =
        await _settingsRepository.isUnknownBlocked();
    if (!isUnknownBlockedSetting) return false;

    try {
      final savedContacts = _contactsController.contacts;
      return !savedContacts.any(
        (contact) =>
            normalizePhone(contact.phoneNumber) == normalizedPhoneNumber,
      );
    } catch (e) {
      log(
        '[BlockedNumbers] Error checking unknown number with contacts getter: $e',
      );
      return false;
    }
  }

  /// 사용자가 직접 차단한 번호인지 확인
  Future<bool> isUserBlockedAsync(String normalizedPhoneNumber) async {
    final userBlockedList =
        await _blockedNumberRepository.getAllUserBlockedNumbers();
    return userBlockedList.any(
      (blockedNum) =>
          normalizedPhoneNumber.contains(normalizePhone(blockedNum)),
    );
  }

  /// 위험 번호 자동 차단 설정에 따라 차단 여부 확인
  Future<bool> isDangerBlockedAsync(String normalizedPhoneNumber) async {
    final isAutoBlockDangerSetting =
        await _settingsRepository.isAutoBlockDanger();
    if (!isAutoBlockDangerSetting) return false;

    final dangerList = await _blockedNumberRepository.getDangerNumbers();
    return dangerList
        .map((d) => normalizePhone(d))
        .contains(normalizedPhoneNumber);
  }

  /// 콜폭 번호 차단 설정에 따라 차단 여부 확인
  Future<bool> isBombCallBlockedAsync(String normalizedPhoneNumber) async {
    final isBombCallsBlockedSetting =
        await _settingsRepository.isBombCallsBlocked();
    if (!isBombCallsBlockedSetting) return false;

    final bombList = await _blockedNumberRepository.getBombNumbers();
    return bombList
        .map((b) => normalizePhone(b))
        .contains(normalizedPhoneNumber);
  }

  @Deprecated('Use isNumberBlockedAsync instead')
  bool isNumberBlocked(String phoneNumber, {bool addHistory = false}) {
    log(
      '[BlockedNumbers] Warning: Synchronous isNumberBlocked called. Returns false.',
    );
    return false;
  }
}
