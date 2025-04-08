import 'dart:async';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:mobile/controllers/search_records_controller.dart';
import 'package:phone_state/phone_state.dart';
import 'package:mobile/controllers/call_log_controller.dart';
import 'package:mobile/services/native_default_dialer_methods.dart';
import 'package:mobile/models/search_result_model.dart';
import 'package:flutter_background_service/flutter_background_service.dart';

class PhoneStateController {
  final GlobalKey<NavigatorState> navKey;
  final CallLogController callLogController;
  PhoneStateController(this.navKey, this.callLogController);

  StreamSubscription<PhoneState>? _subscription;

  void startListening() {
    _subscription = PhoneState.stream.listen((event) async {
      switch (event.status) {
        case PhoneStateStatus.NOTHING:
          _onNothing();
          break;
        case PhoneStateStatus.CALL_INCOMING:
          if (event.number != null && event.number != '') {
            await _onIncoming(event.number);
          }
          break;
        case PhoneStateStatus.CALL_STARTED:
          break;
        case PhoneStateStatus.CALL_ENDED:
          if (event.number != null && event.number != '') {
            await _onCallEnded(event.number);
          }
          break;
      }
    });
  }

  void stopListening() {
    _subscription?.cancel();
    _subscription = null;
  }

  void _onNothing() {
    log('[PhoneState] NOTHING');
  }

  // PhoneStateController._onIncoming
  Future<void> _onIncoming(String? number) async {
    final isDef = await NativeDefaultDialerMethods.isDefaultDialer();

    if (!isDef && await FlutterOverlayWindow.isPermissionGranted()) {
      log('showOverlay');
      final phoneData = await SearchRecordsController.searchPhone(number!);
      final todayRecords = await SearchRecordsController.searchTodayRecord(
        number,
      );

      final searchResult = SearchResultModel(
        phoneNumberModel: phoneData,
        todayRecords: todayRecords,
      );

      final data = searchResult.toJson();
      data['phoneNumber'] = number;

      FlutterOverlayWindow.shareData(data);
      log('showOverlay done');
    }
    log('[PhoneState] not default => overlay shown for $number');
  }

  Future<void> _onCallEnded(String? number) async {
    log('[PhoneState] callEnded for number: $number');

    final isDef = await NativeDefaultDialerMethods.isDefaultDialer();
    log('[PhoneState] Is default dialer: $isDef');

    // 기본 전화앱이 *아닌* 경우에도 로그 갱신 및 업로드 요청
    if (!isDef) {
      log('[PhoneState] Not default dialer, refreshing call logs locally...');
      // 1. 로컬 Hive 저장 및 UI 업데이트 이벤트 발생
      await callLogController.refreshCallLogs();

      // 2. 백그라운드 서비스에 서버 업로드 요청
      final service = FlutterBackgroundService();
      if (await service.isRunning()) {
        log(
          '[PhoneState] Invoking uploadCallLogsNow for background service...',
        );
        service.invoke('uploadCallLogsNow');
      } else {
        log(
          '[PhoneState] Background service not running, cannot request call log upload.',
        );
        // TODO: 서비스 미실행 시 업로드 큐 처리 등 고려
      }
    } else {
      // 기본 전화앱인 경우, NavigationController의 onCallEnded에서 처리됨
      log(
        '[PhoneState] Is default dialer, skipping log refresh here (handled by NavigationController).',
      );
    }
    // 번호 없는 경우는 무시 (이미 앞 단계에서 체크됨)
  }
}
