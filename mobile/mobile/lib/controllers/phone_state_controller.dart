import 'dart:async';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:get_storage/get_storage.dart';
import 'package:mobile/controllers/search_records_controller.dart';
import 'package:phone_state/phone_state.dart';
import 'package:mobile/controllers/call_log_controller.dart';
import 'package:mobile/services/native_default_dialer_methods.dart';
import 'package:mobile/models/search_result_model.dart';

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
        number!,
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
    log('[PhoneState] callEnded => sync logs');

    final isDef = await NativeDefaultDialerMethods.isDefaultDialer();
    if (!isDef) {
      callLogController.refreshCallLogs();
    }
  }
}
