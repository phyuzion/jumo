import 'dart:async';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window_sdk34/flutter_overlay_window_sdk34.dart';
import 'package:mobile/controllers/search_records_controller.dart';
import 'package:phone_state/phone_state.dart';
import 'package:mobile/controllers/call_log_controller.dart';
import 'package:mobile/controllers/contacts_controller.dart';
import 'package:mobile/controllers/navigation_controller.dart';
import 'package:mobile/services/native_default_dialer_methods.dart';
import 'package:mobile/models/search_result_model.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter/services.dart';
import 'package:mobile/models/phone_book_model.dart';
import 'package:mobile/utils/constants.dart';

class PhoneStateController with WidgetsBindingObserver {
  final GlobalKey<NavigatorState> navigatorKey;
  final CallLogController callLogController;
  final ContactsController contactsController;

  PhoneStateController(
    this.navigatorKey,
    this.callLogController,
    this.contactsController,
  ) {
    WidgetsBinding.instance.addObserver(this);
  }

  StreamSubscription<PhoneState>? _phoneStateSubscription;

  void startListening() {
    _phoneStateSubscription = PhoneState.stream.listen((event) async {
      final isDef = await NativeDefaultDialerMethods.isDefaultDialer();
      if (isDef) return;

      String? number = event.number;

      switch (event.status) {
        case PhoneStateStatus.NOTHING:
          _onNothing();
          if (number != null && number.isNotEmpty) {
            notifyServiceCallState('onCallEnded', number, '');
          }
          break;
        case PhoneStateStatus.CALL_INCOMING:
          if (number != null && number.isNotEmpty) {
            await _onIncoming(number);
            notifyServiceCallState('onIncomingNumber', number, '');
          }
          break;
        case PhoneStateStatus.CALL_STARTED:
          if (number != null && number.isNotEmpty) {
            await _onCallStarted(number);
            notifyServiceCallState('onCall', number, '', connected: true);
          }
          break;
        case PhoneStateStatus.CALL_ENDED:
          if (number != null && number.isNotEmpty) {
            await _onCallEnded(number);
            notifyServiceCallState('onCallEnded', number, '');
          }
          break;
      }
    });
  }

  void stopListening() {
    _phoneStateSubscription?.cancel();
    _phoneStateSubscription = null;
  }

  void _onNothing() {
    log('[PhoneState] NOTHING');
  }

  Future<void> _onIncoming(String? number) async {
    if (number == null || number.isEmpty) return;

    final isDef = await NativeDefaultDialerMethods.isDefaultDialer();
    log(
      '[PhoneStateController] Incoming call: $number, Is default dialer: $isDef',
    );

    if (isDef) {
      final callerName = await contactsController.getContactName(number);
      log(
        '[PhoneStateController] Default Dialer: Notifying service for $number, name: $callerName',
      );
      notifyServiceCallState('onIncomingNumber', number, callerName);
      return;
    }

    if (await FlutterOverlayWindow.isPermissionGranted()) {
      log(
        '[PhoneStateController] Overlay permission granted for incoming call: $number',
      );

      final ringingData = {'type': 'ringing', 'phoneNumber': number};
      try {
        await FlutterOverlayWindow.shareData(ringingData);
        log(
          '[PhoneStateController] Sent ringing state to overlay: $ringingData',
        );
      } catch (e) {
        log('[PhoneStateController] Error sending ringing state: $e');
      }

      SearchResultModel? searchResultModel;
      try {
        final phoneData = await SearchRecordsController.searchPhone(number);
        final todayRecords = await SearchRecordsController.searchTodayRecord(
          number,
        );

        if (phoneData != null ||
            (todayRecords != null && todayRecords.isNotEmpty)) {
          searchResultModel = SearchResultModel(
            phoneNumberModel: phoneData,
            todayRecords: todayRecords,
          );
        }
        log(
          '[PhoneStateController] Search completed for $number. Result found: ${searchResultModel != null}',
        );
      } catch (e) {
        log('[PhoneStateController] Error during search for $number: $e');
        searchResultModel = null;
      }

      final resultData = {
        'type': 'result',
        'phoneNumber': number,
        'searchResult': searchResultModel?.toJson(),
      };
      try {
        await FlutterOverlayWindow.shareData(resultData);
        log(
          '[PhoneStateController] Sent result state to overlay: type=result, number=$number, hasResult=${searchResultModel != null}',
        );
      } catch (e) {
        log('[PhoneStateController] Error sending result state: $e');
      }
    } else {
      log(
        '[PhoneStateController] Overlay permission not granted for incoming call: $number',
      );
      final callerName = await contactsController.getContactName(number);
      log(
        '[PhoneStateController] No Overlay Permission: Notifying service for $number, name: $callerName',
      );
      notifyServiceCallState('onIncomingNumber', number, callerName);
    }
  }

  Future<void> _onCallStarted(String? number) async {
    log('[PhoneState] callStarted for number: $number');
    if (number != null && number.isNotEmpty) {
      final callerName = await contactsController.getContactName(number);
      notifyServiceCallState('onCall', number, callerName, connected: true);
    }
  }

  Future<void> _onCallEnded(String? number) async {
    log('[PhoneState] callEnded for number: $number');

    final isDef = await NativeDefaultDialerMethods.isDefaultDialer();
    log('[PhoneState] Is default dialer: $isDef');

    if (number != null && number.isNotEmpty) {
      final callerName = await contactsController.getContactName(number);
      notifyServiceCallState('onCallEnded', number, callerName);
    }
  }

  void notifyServiceCallState(
    String stateMethod,
    String number,
    String callerName, {
    bool? connected,
    String? reason,
  }) {
    log(
      '[PhoneStateController][notifyServiceCallState] Method called: stateMethod=$stateMethod, number=$number, name=$callerName, connected=$connected',
    );

    final service = FlutterBackgroundService();
    String state;
    bool isConnectedValue = connected ?? false;
    String reasonValue = reason ?? '';

    switch (stateMethod) {
      case 'onIncomingNumber':
        state = 'incoming';
        break;
      case 'onCall':
        state = 'active';
        break;
      case 'onCallEnded':
        state = 'ended';
        break;
      default:
        state = 'unknown';
    }

    if (state == 'unknown') {
      log(
        '[PhoneStateController][notifyServiceCallState] Unknown stateMethod $stateMethod, not invoking service.',
      );
      return;
    }

    final payload = {
      'state': state,
      'number': number,
      'callerName': callerName.isNotEmpty ? callerName : '알 수 없음',
      'connected': isConnectedValue,
      'reason': reasonValue,
    };

    log(
      '[PhoneStateController][notifyServiceCallState] Invoking service with callStateChanged. Payload: $payload',
    );
    try {
      service.invoke('callStateChanged', payload);
      log(
        '[PhoneStateController][notifyServiceCallState] Successfully invoked service with callStateChanged.',
      );
    } catch (e) {
      log(
        '[PhoneStateController][notifyServiceCallState] Error invoking service: $e',
      );
    }
  }

  void _processIncomingCall(String number, String callerName) async {
    // Implementation of _processIncomingCall method
  }

  void _processCallStart(String number, String callerName) async {
    // Implementation of _processCallStart method
  }

  void _processCallEnd(String number) async {
    // Implementation of _processCallEnd method
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Implementation of didChangeAppLifecycleState method
  }
}
