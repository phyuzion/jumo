import 'dart:developer';
import 'package:flutter/widgets.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:mobile/graphql/block_api.dart';
import 'package:mobile/graphql/search_api.dart';
import 'package:mobile/repositories/blocked_number_repository.dart';
import 'package:mobile/repositories/settings_repository.dart';
import 'package:mobile/utils/constants.dart';
import 'package:provider/provider.dart';

class BlockListenerService {
  final BuildContext context;
  final FlutterBackgroundService _service;

  BlockListenerService(this.context, this._service) {
    _setupListeners();
  }

  void _setupListeners() {
    // 차단 목록 관련 리스너들
    _service
        .on('requestUserBlockedNumbers')
        .listen(_handleRequestUserBlockedNumbers);
    _service.on('requestSettings').listen(_handleRequestSettings);
    _service.on('requestDangerNumbers').listen(_handleRequestDangerNumbers);
    _service.on('requestBombNumbers').listen(_handleRequestBombNumbers);
    _service.on('handleRequestBombNumbers').listen(_handleRequestBombNumbers);
    _service.on('saveUserBlockedNumbers').listen(_handleSaveUserBlockedNumbers);
    _service.on('saveDangerNumbers').listen(_handleSaveDangerNumbers);
    _service.on('saveBombNumbers').listen(_handleSaveBombNumbers);
    _service.on('clearDangerNumbers').listen(_handleClearDangerNumbers);
    _service.on('clearBombNumbers').listen(_handleClearBombNumbers);

    // 사용자 차단 번호 직접 업데이트 이벤트 처리
    _service
        .on('updateUserBlockedNumbers')
        .listen(_handleUpdateUserBlockedNumbers);

    // 블록 목록 동기화 요청 처리
    _service.on('syncBlockedListsNow').listen((_) {
      log('[BlockListenerService] Received syncBlockedListsNow request');
      _requestUserBlockedNumbers();
      _requestSettings();
    });
  }

  void _requestUserBlockedNumbers() {
    log('[BlockListenerService] Requesting user blocked numbers');
    _handleRequestUserBlockedNumbers(null);
  }

  void _requestSettings() {
    log('[BlockListenerService] Requesting settings');
    _handleRequestSettings(null);
  }

  void _handleRequestUserBlockedNumbers(Map<String, dynamic>? event) async {
    if (!context.mounted) return;
    log('[BlockListenerService] Processing requestUserBlockedNumbers');

    try {
      log('[BlockListenerService] API 호출 시작: BlockApi.getUserBlockedNumbers()');
      final blockedNumbers = await BlockApi.getUserBlockedNumbers();
      log(
        '[BlockListenerService] API 호출 완료: ${blockedNumbers?.length ?? 0}개 사용자 차단 번호 가져옴',
      );
      _service.invoke('userBlockedNumbersResponse', {
        'numbers': blockedNumbers ?? [],
      });
      log('[BlockListenerService] userBlockedNumbersResponse 이벤트 발송 완료');
    } catch (e) {
      log('[BlockListenerService] Error fetching user blocked numbers: $e');
      _service.invoke('userBlockedNumbersResponse', {
        'numbers': [],
        'error': e.toString(),
      });
    }
  }

  void _handleRequestSettings(Map<String, dynamic>? event) async {
    if (!context.mounted) return;
    log('[BlockListenerService] Processing requestSettings');

    try {
      final settingsRepository = context.read<SettingsRepository>();
      log(
        '[BlockListenerService] 설정 로드 시작: isAutoBlockDanger, isBombCallsBlocked, bombCallsCount',
      );
      final isAutoBlockDanger = await settingsRepository.isAutoBlockDanger();
      final isBombCallsBlocked = await settingsRepository.isBombCallsBlocked();
      final bombCallsCount = await settingsRepository.getBombCallsCount();

      log(
        '[BlockListenerService] 설정 로드 완료 - AutoBlockDanger: $isAutoBlockDanger, BombCallsBlocked: $isBombCallsBlocked ($bombCallsCount)',
      );

      _service.invoke('settingsResponse', {
        'isAutoBlockDanger': isAutoBlockDanger,
        'isBombCallsBlocked': isBombCallsBlocked,
        'bombCallsCount': bombCallsCount,
      });
      log('[BlockListenerService] settingsResponse 이벤트 발송 완료');
    } catch (e) {
      log('[BlockListenerService] Error fetching settings: $e');
      _service.invoke('settingsResponse', {
        'isAutoBlockDanger': false,
        'isBombCallsBlocked': false,
        'bombCallsCount': 0,
        'error': e.toString(),
      });
    }
  }

  void _handleRequestDangerNumbers(Map<String, dynamic>? event) async {
    if (!context.mounted) return;
    log('[BlockListenerService] Processing requestDangerNumbers');

    try {
      log(
        '[BlockListenerService] API 호출 시작: SearchApi.getPhoneNumbersByType(99)',
      );
      final dangerNumbersResult = await SearchApi.getPhoneNumbersByType(99);
      final dangerNumbersList =
          dangerNumbersResult.map((n) => n.phoneNumber).toList();
      log(
        '[BlockListenerService] API 호출 완료: ${dangerNumbersList.length}개 위험 번호 가져옴',
      );
      _service.invoke('dangerNumbersResponse', {'numbers': dangerNumbersList});
      log('[BlockListenerService] dangerNumbersResponse 이벤트 발송 완료');
    } catch (e) {
      log('[BlockListenerService] Error fetching danger numbers: $e');
      _service.invoke('dangerNumbersResponse', {
        'numbers': [],
        'error': e.toString(),
      });
    }
  }

  void _handleRequestBombNumbers(Map<String, dynamic>? event) async {
    if (!context.mounted) return;
    final count = event?['count'] as int? ?? 0;
    log('[BlockListenerService] Processing requestBombNumbers (count: $count)');

    try {
      // 요청된 카운트와 설정된 카운트 모두 로깅
      final settingsRepository = context.read<SettingsRepository>();
      final isBombCallsBlocked = await settingsRepository.isBombCallsBlocked();
      final settingsBombCallsCount =
          await settingsRepository.getBombCallsCount();

      log(
        '[BlockListenerService] 요청된 콜폭 횟수: $count, 설정값: $settingsBombCallsCount, 활성화됨: $isBombCallsBlocked',
      );

      // 설정과 요청 값이 다른 경우 설정 업데이트 (직접 요청 시)
      if (count > 0 && count != settingsBombCallsCount) {
        log(
          '[BlockListenerService] 설정값과 요청값이 다름 - 설정 업데이트: $settingsBombCallsCount → $count',
        );
        await settingsRepository.setBombCallsCount(count);
      }

      // 콜폭 차단이 비활성화된 경우 로그만 남기고 처리 건너뜀
      if (!isBombCallsBlocked) {
        log('[BlockListenerService] 콜폭 차단 비활성화 상태 - API 호출 건너뜀');
        _service.invoke('bombNumbersResponse', {'numbers': []});
        return;
      }

      // 실제 카운트가 0이면 API 호출 건너뜀
      final actualCount = count > 0 ? count : settingsBombCallsCount;
      if (actualCount <= 0) {
        log('[BlockListenerService] 콜폭 차단 횟수가 0 이하 - API 호출 건너뜀');
        _service.invoke('bombNumbersResponse', {'numbers': []});
        return;
      }

      log(
        '[BlockListenerService] API 호출 시작: BlockApi.getBombCallBlockNumbers($actualCount)',
      );
      final bombNumbersResult = await BlockApi.getBombCallBlockNumbers(
        actualCount,
      );
      final bombNumbersList =
          (bombNumbersResult ?? [])
              .map((n) => n['phoneNumber'] as String? ?? '')
              .toList();
      log(
        '[BlockListenerService] API 호출 완료: ${bombNumbersList.length}개 콜폭 번호 가져옴',
      );
      _service.invoke('bombNumbersResponse', {'numbers': bombNumbersList});
      log('[BlockListenerService] bombNumbersResponse 이벤트 발송 완료');
    } catch (e) {
      log('[BlockListenerService] Error fetching bomb numbers: $e');
      _service.invoke('bombNumbersResponse', {
        'numbers': [],
        'error': e.toString(),
      });
    }
  }

  void _handleSaveUserBlockedNumbers(Map<String, dynamic>? event) async {
    if (!context.mounted) return;
    final numbers = event?['numbers'] as List<dynamic>? ?? [];
    log(
      '[BlockListenerService] Processing saveUserBlockedNumbers (count: ${numbers.length})',
    );

    try {
      final repository = context.read<BlockedNumberRepository>();
      final normalized =
          numbers.map((n) => normalizePhone(n.toString())).toList();
      await repository.saveAllUserBlockedNumbers(normalized);
      log(
        '[BlockListenerService] Saved user blocked numbers: ${normalized.length}',
      );
    } catch (e) {
      log('[BlockListenerService] Error saving user blocked numbers: $e');
    }
  }

  void _handleSaveDangerNumbers(Map<String, dynamic>? event) async {
    if (!context.mounted) return;
    final numbers = event?['numbers'] as List<dynamic>? ?? [];
    log(
      '[BlockListenerService] Processing saveDangerNumbers (count: ${numbers.length})',
    );

    try {
      final repository = context.read<BlockedNumberRepository>();
      final normalized =
          numbers.map((n) => normalizePhone(n.toString())).toList();
      await repository.saveDangerNumbers(normalized);
      log('[BlockListenerService] Saved danger numbers: ${normalized.length}');
    } catch (e) {
      log('[BlockListenerService] Error saving danger numbers: $e');
    }
  }

  void _handleSaveBombNumbers(Map<String, dynamic>? event) async {
    if (!context.mounted) return;
    final numbers = event?['numbers'] as List<dynamic>? ?? [];
    log(
      '[BlockListenerService] Processing saveBombNumbers (count: ${numbers.length})',
    );

    try {
      final repository = context.read<BlockedNumberRepository>();
      final normalized =
          numbers.map((n) => normalizePhone(n.toString())).toList();
      await repository.saveBombNumbers(normalized);
      log('[BlockListenerService] Saved bomb numbers: ${normalized.length}');
    } catch (e) {
      log('[BlockListenerService] Error saving bomb numbers: $e');
    }
  }

  void _handleClearDangerNumbers(Map<String, dynamic>? event) async {
    if (!context.mounted) return;
    log('[BlockListenerService] Processing clearDangerNumbers');

    try {
      final repository = context.read<BlockedNumberRepository>();
      await repository.clearDangerNumbers();
      log('[BlockListenerService] Cleared danger numbers');
    } catch (e) {
      log('[BlockListenerService] Error clearing danger numbers: $e');
    }
  }

  void _handleClearBombNumbers(Map<String, dynamic>? event) async {
    if (!context.mounted) return;
    log('[BlockListenerService] Processing clearBombNumbers');

    try {
      final repository = context.read<BlockedNumberRepository>();
      await repository.clearBombNumbers();
      log('[BlockListenerService] Cleared bomb numbers');
    } catch (e) {
      log('[BlockListenerService] Error clearing bomb numbers: $e');
    }
  }

  // 사용자 차단 번호 직접 업데이트 처리
  void _handleUpdateUserBlockedNumbers(Map<String, dynamic>? event) async {
    if (!context.mounted) return;
    final numbers = event?['numbers'] as List<dynamic>? ?? [];
    log('[BlockListenerService] 사용자 차단 번호 직접 업데이트 요청 수신 (${numbers.length}개)');

    try {
      // 로컬 저장소에 저장하는 부분 제거 (이미 BlockedNumbersController에서 저장했음)
      final normalized =
          numbers.map((n) => normalizePhone(n.toString())).toList();

      // 서버 API 호출하여 업데이트
      log('[BlockListenerService] 서버 API 호출 시작: BlockApi.updateBlockedNumbers');
      await BlockApi.updateBlockedNumbers(normalized);
      log('[BlockListenerService] 서버 API 호출 완료: 사용자 차단 번호 업데이트됨');
    } catch (e) {
      log('[BlockListenerService] 사용자 차단 번호 업데이트 오류: $e');
    }
  }
}
