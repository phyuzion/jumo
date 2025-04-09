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
      String callerName = '';

      if (number != null && number.isNotEmpty) {
        callerName = await getContactName(number);
      }

      switch (event.status) {
        case PhoneStateStatus.NOTHING:
          _onNothing();
          if (number != null && number.isNotEmpty) {
            notifyServiceCallState('onCallEnded', number, callerName);
          }
          break;
        case PhoneStateStatus.CALL_INCOMING:
          if (number != null && number.isNotEmpty) {
            await _onIncoming(number);
            notifyServiceCallState('onIncomingNumber', number, callerName);
          }
          break;
        case PhoneStateStatus.CALL_STARTED:
          if (number != null && number.isNotEmpty) {
            await _onCallStarted(number);
            notifyServiceCallState(
              'onCall',
              number,
              callerName,
              connected: true,
            );
          }
          break;
        case PhoneStateStatus.CALL_ENDED:
          if (number != null && number.isNotEmpty) {
            await _onCallEnded(number);
            notifyServiceCallState('onCallEnded', number, callerName);
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

    if (number != null && number.isNotEmpty) {
      final callerName = await getContactName(number);
      notifyServiceCallState('onIncomingNumber', number, callerName);
    }
  }

  Future<void> _onCallStarted(String? number) async {
    log('[PhoneState] callStarted for number: $number');
    if (number != null && number.isNotEmpty) {
      final callerName = await getContactName(number);
      notifyServiceCallState('onCall', number, callerName, connected: true);
    }
  }

  Future<void> _onCallEnded(String? number) async {
    log('[PhoneState] callEnded for number: $number');

    final isDef = await NativeDefaultDialerMethods.isDefaultDialer();
    log('[PhoneState] Is default dialer: $isDef');

    if (!isDef) {
      log('[PhoneState] Waiting a moment for call log to be written...');
      await Future.delayed(const Duration(seconds: 2));

      log('[PhoneState] Not default dialer, refreshing call logs locally...');
      await callLogController.refreshCallLogs();

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
      }
    } else {
      log('[PhoneState] Is default dialer, skipping log refresh here.');
    }

    if (number != null && number.isNotEmpty) {
      final callerName = await getContactName(number);
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
        '[PhoneStateController] Unknown stateMethod $stateMethod, not invoking service.',
      );
      return;
    }

    log(
      '[PhoneStateController] Invoking service: callStateChanged - state: $state, number: $number, name: $callerName, connected: $isConnectedValue, reason: $reasonValue',
    );
    service.invoke('callStateChanged', {
      'state': state,
      'number': number,
      'callerName': callerName.isNotEmpty ? callerName : '알 수 없음',
      'connected': isConnectedValue,
      'reason': reasonValue,
    });
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

  Future<String> getContactName(String phoneNumber) async {
    final normalizedNumber = normalizePhone(phoneNumber);
    try {
      final List<PhoneBookModel> contacts =
          await contactsController.getLocalContacts();
      final contact = contacts.firstWhere(
        (c) => c.phoneNumber == normalizedNumber,
        orElse: () => PhoneBookModel(contactId: '', name: '', phoneNumber: ''),
      );

      if (contact.name.isNotEmpty && contact.name != '(No Name)') {
        return contact.name;
      }
    } catch (e) {
      log(
        '[PhoneStateController] Error getting contact name for $normalizedNumber: $e',
      );
    }
    return '';
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Implementation of didChangeAppLifecycleState method
  }
}
