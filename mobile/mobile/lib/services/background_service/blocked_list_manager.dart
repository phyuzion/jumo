import 'dart:developer';
import 'package:mobile/utils/constants.dart';
import 'package:mobile/graphql/search_api.dart';
import 'package:mobile/graphql/block_api.dart';
import 'package:mobile/repositories/auth_repository.dart';
import 'package:mobile/repositories/settings_repository.dart';
import 'package:mobile/repositories/blocked_number_repository.dart';
import 'package:mobile/main.dart';

class BlockedListManager {
  Future<void> syncBlockedLists() async {
    log(
      '[BlockedListManager] Executing syncBlockedLists (User, Danger, Bomb)...',
    );

    // Repository 인스턴스 가져오기
    late SettingsRepository settingsRepository;
    late BlockedNumberRepository blockedNumberRepository;

    try {
      settingsRepository = getIt<SettingsRepository>();
      blockedNumberRepository = getIt<BlockedNumberRepository>();
    } catch (e) {
      log(
        '[BlockedListManager][syncBlockedLists] Failed to get Repositories from GetIt: $e',
      );
      return;
    }

    try {
      // 1. 서버에서 사용자 차단 목록 가져와 Repository 통해 저장
      log('[BlockedListManager] Syncing user blocked numbers...');
      try {
        final serverNumbers = await BlockApi.getBlockedNumbers();
        final numbersToSave =
            (serverNumbers ?? []).map((n) => normalizePhone(n)).toList();
        // Repository 사용
        await blockedNumberRepository.saveAllUserBlockedNumbers(numbersToSave);
        log(
          '[BlockedListManager] Synced user blocked numbers: ${numbersToSave.length}',
        );
      } catch (e) {
        log('[BlockedListManager] Error syncing user blocked numbers: $e');
      }

      // 2. 위험 번호 업데이트 (SettingsRepository 및 BlockedNumberRepository 사용)
      final isAutoBlockDanger = await settingsRepository.isAutoBlockDanger();
      if (isAutoBlockDanger) {
        log('[BlockedListManager] Syncing danger numbers...');
        try {
          final dangerNumbersResult = await SearchApi.getPhoneNumbersByType(99);
          final dangerNumbersList =
              dangerNumbersResult
                  .map((n) => normalizePhone(n.phoneNumber))
                  .toList();
          // Repository 사용
          await blockedNumberRepository.saveDangerNumbers(dangerNumbersList);
          log(
            '[BlockedListManager] Synced danger numbers: ${dangerNumbersList.length}',
          );
        } catch (e) {
          log('[BlockedListManager] Error syncing danger numbers: $e');
        }
      } else {
        // Repository 사용
        await blockedNumberRepository.clearDangerNumbers();
        log(
          '[BlockedListManager] Cleared local danger numbers as setting is off.',
        );
      }

      // 3. 콜폭 번호 업데이트 (SettingsRepository 및 BlockedNumberRepository 사용)
      final isBombCallsBlocked = await settingsRepository.isBombCallsBlocked();
      final bombCallsCount = await settingsRepository.getBombCallsCount();
      if (isBombCallsBlocked && bombCallsCount > 0) {
        log(
          '[BlockedListManager] Syncing bomb call numbers (count: $bombCallsCount)...',
        );
        try {
          final bombNumbersResult = await BlockApi.getBlockNumbers(
            bombCallsCount,
          );
          final bombNumbersList =
              (bombNumbersResult ?? [])
                  .map((n) => normalizePhone(n['phoneNumber'] as String? ?? ''))
                  .toList();
          // Repository 사용
          await blockedNumberRepository.saveBombNumbers(bombNumbersList);
          log(
            '[BlockedListManager] Synced bomb call numbers: ${bombNumbersList.length}',
          );
        } catch (e) {
          log('[BlockedListManager] Error syncing bomb call numbers: $e');
        }
      } else {
        // Repository 사용
        await blockedNumberRepository.clearBombNumbers();
        log(
          '[BlockedListManager] Cleared local bomb call numbers as setting is off.',
        );
      }

      log('[BlockedListManager] syncBlockedLists finished.');
    } catch (e, st) {
      log(
        '[BlockedListManager] General error during syncBlockedLists: $e\n$st',
      );
    }
  }
}
