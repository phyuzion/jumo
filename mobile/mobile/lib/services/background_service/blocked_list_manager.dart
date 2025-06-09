import 'dart:developer';
import 'dart:async';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:mobile/utils/constants.dart';
import 'package:mobile/graphql/search_api.dart';
import 'package:mobile/graphql/block_api.dart';
import 'package:mobile/repositories/auth_repository.dart';
import 'package:mobile/repositories/settings_repository.dart';
import 'package:mobile/repositories/blocked_number_repository.dart';
import 'package:mobile/main.dart';

class BlockedListManager {
  final ServiceInstance _service;
  Timer? _syncTimer;
  static const Duration _syncInterval = Duration(hours: 1);

  BlockedListManager(this._service);

  void initialize() {
    _setupEventListeners();
    _setupPeriodicSync();
  }

  void _setupPeriodicSync() {
    // 초기 동기화 요청 (지연 시작)
    Future.delayed(const Duration(seconds: 5), () {
      syncBlockedLists();
    });

    // 주기적 동기화 타이머 설정
    _syncTimer = Timer.periodic(_syncInterval, (_) {
      syncBlockedLists();
    });
  }

  void syncBlockedLists() {
    log('[BlockedListManager] Requesting blocked lists sync...');
    _service.invoke('syncBlockedListsNow');
  }

  void _setupEventListeners() {
    // 사용자 차단 목록 응답 처리
    _service.on('userBlockedNumbersResponse').listen((event) {
      try {
        final numbers = event?['numbers'] as List<dynamic>? ?? [];
        log('[BlockedListManager] 사용자 직접 차단 번호 ${numbers.length}개 수신됨');

        if (numbers.isNotEmpty && numbers.length < 10) {
          // 적은 수의 번호인 경우만 모든 번호 로깅 (로그 줄이기)
          log('[BlockedListManager] 사용자 차단 번호: $numbers');
        } else if (numbers.isNotEmpty) {
          // 많은 수의 번호는 첫 번째 번호만 샘플로 로깅
          log('[BlockedListManager] 사용자 차단 번호 샘플: ${numbers.first}');
        }

        _service.invoke('saveUserBlockedNumbers', {'numbers': numbers});
      } catch (e) {
        log('[BlockedListManager] Error processing user blocked numbers: $e');
      }
    });

    // 사용자 차단 번호 직접 업데이트 처리
    _service.on('updateUserBlockedNumbers').listen((event) {
      final numbers = event?['numbers'] as List<dynamic>? ?? [];
      log('[BlockedListManager] 사용자 차단 번호 직접 업데이트 요청 수신 (${numbers.length}개)');
      _service.invoke('updateUserBlockedNumbers', {'numbers': numbers});
    });

    // 설정 응답 처리
    _service.on('settingsResponse').listen((event) {
      try {
        final isAutoBlockDanger = event?['isAutoBlockDanger'] as bool? ?? false;
        final isBombCallsBlocked =
            event?['isBombCallsBlocked'] as bool? ?? false;
        final bombCallsCount = event?['bombCallsCount'] as int? ?? 0;

        log(
          '[BlockedListManager] 차단 설정 수신 - 위험번호자동차단: $isAutoBlockDanger, 콜폭차단: $isBombCallsBlocked (${bombCallsCount}회)',
        );

        // 설정에 따라 데이터 요청
        if (isAutoBlockDanger) {
          log('[BlockedListManager] 위험 번호 자동 차단 활성화됨 → 위험 번호 요청');
          _service.invoke('requestDangerNumbers');
        } else {
          log('[BlockedListManager] 위험 번호 자동 차단 비활성화됨 → 위험 번호 제거');
          _service.invoke('clearDangerNumbers');
        }

        if (isBombCallsBlocked && bombCallsCount > 0) {
          log(
            '[BlockedListManager] 콜폭 차단 활성화됨 (횟수: $bombCallsCount) → 콜폭 번호 요청',
          );
          _service.invoke('handleRequestBombNumbers', {
            'count': bombCallsCount,
          });
        } else {
          log('[BlockedListManager] 콜폭 차단 비활성화됨 → 콜폭 번호 제거');
          _service.invoke('clearBombNumbers');
        }
      } catch (e) {
        log('[BlockedListManager] Error processing settings response: $e');
      }
    });

    // 직접 콜폭 번호 요청 처리 (설정 화면에서 직접 호출)
    _service.on('requestBombNumbers').listen((event) {
      final count = event?['count'] as int? ?? 0;
      if (count > 0) {
        log('[BlockedListManager] 콜폭 번호 직접 요청 수신 (count: $count)');
        _service.invoke('handleRequestBombNumbers', {'count': count});
      }
    });

    // 위험 번호 응답 처리
    _service.on('dangerNumbersResponse').listen((event) {
      try {
        final numbers = event?['numbers'] as List<dynamic>? ?? [];
        log('[BlockedListManager] 위험 번호 ${numbers.length}개 수신됨');

        if (numbers.isNotEmpty && numbers.length < 5) {
          // 적은 수의 번호인 경우만 모든 번호 로깅 (로그 줄이기)
          log('[BlockedListManager] 위험 번호 목록: $numbers');
        } else if (numbers.isNotEmpty) {
          // 많은 수의 번호는 첫 번째 번호만 샘플로 로깅
          log('[BlockedListManager] 위험 번호 샘플: ${numbers.first}');
        }

        _service.invoke('saveDangerNumbers', {'numbers': numbers});
      } catch (e) {
        log('[BlockedListManager] Error processing danger numbers: $e');
      }
    });

    // 콜폭 번호 응답 처리
    _service.on('bombNumbersResponse').listen((event) {
      try {
        final numbers = event?['numbers'] as List<dynamic>? ?? [];
        log('[BlockedListManager] 콜폭 번호 ${numbers.length}개 수신됨');

        if (numbers.isNotEmpty && numbers.length < 5) {
          // 적은 수의 번호인 경우만 모든 번호 로깅 (로그 줄이기)
          log('[BlockedListManager] 콜폭 번호 목록: $numbers');
        } else if (numbers.isNotEmpty) {
          // 많은 수의 번호는 첫 번째 번호만 샘플로 로깅
          log('[BlockedListManager] 콜폭 번호 샘플: ${numbers.first}');
        }

        _service.invoke('saveBombNumbers', {'numbers': numbers});
      } catch (e) {
        log('[BlockedListManager] Error processing bomb numbers: $e');
      }
    });
  }
}
