import 'dart:async';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:phone_state/phone_state.dart';
import 'package:mobile/providers/call_state_provider.dart';
import 'package:mobile/controllers/call_log_controller.dart';
import 'package:mobile/controllers/contacts_controller.dart';
import 'package:mobile/controllers/blocked_numbers_controller.dart';
import 'package:mobile/services/native_default_dialer_methods.dart';
import 'package:mobile/services/native_methods.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:mobile/utils/constants.dart';

class PhoneStateController with WidgetsBindingObserver {
  final GlobalKey<NavigatorState> navigatorKey;
  final CallLogController callLogController;
  final ContactsController contactsController;
  final BlockedNumbersController _blockedNumbersController;

  PhoneStateController(
    this.navigatorKey,
    this.callLogController,
    this.contactsController,
    this._blockedNumbersController,
  ) {
    WidgetsBinding.instance.addObserver(this);
  }

  StreamSubscription<PhoneState>? _phoneStateSubscription;

  String? _lastProcessedNumber;
  PhoneStateStatus? _lastProcessedStatus;
  DateTime? _lastProcessedTime;
  String? _rejectedNumber;

  void startListening() {
    _phoneStateSubscription?.cancel();
    _phoneStateSubscription = PhoneState.stream.listen((event) async {
      log(
        '[PhoneStateController][Stream] Received event: ${event.status}, Number: ${event.number}',
      );
      final isDef = await NativeDefaultDialerMethods.isDefaultDialer();
      if (!isDef) {
        await _handlePhoneStateEvent(event.status, event.number);
      } else {
        log(
          '[PhoneStateController][Stream] Default dialer is active, ignoring event from phone_state package.',
        );
      }
    });
  }

  void stopListening() {
    _phoneStateSubscription?.cancel();
    _phoneStateSubscription = null;
    log('[PhoneStateController] Stopped listening to phone state stream.');
  }

  Future<void> handleNativeEvent(
    String method,
    dynamic args,
    bool isDefault,
  ) async {
    log(
      '[PhoneStateController][Native] Received event: $method, Args: $args, IsDefault: $isDefault',
    );
    String number = '';
    bool connected = false;
    String reason = '';
    PhoneStateStatus status = PhoneStateStatus.NOTHING;

    if (args != null) {
      if (args is Map) {
        number = args['number'] as String? ?? '';
        connected = args['connected'] as bool? ?? false;
        reason = args['reason'] as String? ?? '';
      } else if (args is String) {
        number = args;
      }
    }

    switch (method) {
      case 'onIncomingNumber':
        status = PhoneStateStatus.CALL_INCOMING;
        break;
      case 'onCall':
        status =
            connected
                ? PhoneStateStatus.CALL_STARTED
                : PhoneStateStatus.CALL_STARTED;
        break;
      case 'onCallEnded':
        status = PhoneStateStatus.CALL_ENDED;
        break;
    }

    await _handlePhoneStateEvent(
      status,
      number,
      isConnected: connected,
      reason: reason,
    );
  }

  bool _isDuplicateEvent(String? number, PhoneStateStatus? status) {
    final now = DateTime.now();
    log('[_isDuplicateEvent] Checking: number=$number, status=$status');
    log(
      '[_isDuplicateEvent] Last processed: number=$_lastProcessedNumber, status=$_lastProcessedStatus, time=$_lastProcessedTime',
    );

    bool isDup = false;
    if (number == _lastProcessedNumber &&
        status == _lastProcessedStatus &&
        _lastProcessedTime != null &&
        now.difference(_lastProcessedTime!).inSeconds < 2) {
      isDup = true;
    }

    if (!isDup) {
      _lastProcessedNumber = number;
      _lastProcessedStatus = status;
      _lastProcessedTime = now;
      log('[_isDuplicateEvent] Updated last processed info.');
    } else {
      log('[_isDuplicateEvent] Result: Duplicate FOUND!');
    }

    return isDup;
  }

  Future<void> _handlePhoneStateEvent(
    PhoneStateStatus status,
    String? number, {
    bool isConnected = false,
    String? reason,
  }) async {
    if (_isDuplicateEvent(number, status)) {
      log(
        '[_handlePhoneStateEvent] Duplicate event ignored. Number: $number, Status: $status',
      );
      return;
    }
    log(
      '[_handlePhoneStateEvent] Processing event. Number: $number, Status: $status',
    );

    if (number == null || number.isEmpty) {
      if (status == PhoneStateStatus.CALL_ENDED && _rejectedNumber != null) {
        log(
          '[_handlePhoneStateEvent] Ignoring CALL_ENDED event with null number, possibly after rejection.',
        );
        _rejectedNumber = null;
        return;
      }
      if (status == PhoneStateStatus.NOTHING) {
        return;
      }
      return;
    }

    final normalizedNumber = normalizePhone(number);

    if (status == PhoneStateStatus.CALL_ENDED &&
        _rejectedNumber == normalizedNumber) {
      log(
        '[_handlePhoneStateEvent] Ignoring CALL_ENDED event for recently rejected call: $normalizedNumber',
      );
      _rejectedNumber = null;
      return;
    }
    if (status != PhoneStateStatus.CALL_ENDED) {
      _rejectedNumber = null;
    }

    if (status == PhoneStateStatus.CALL_INCOMING) {
      log(
        '[PhoneStateController] Checking block status for incoming call: $normalizedNumber',
      );
      bool isBlocked = false;
      try {
        isBlocked = await _blockedNumbersController.isNumberBlockedAsync(
          normalizedNumber,
          addHistory: true,
        );
      } catch (e) {
        log('[PhoneStateController] Error checking block status: $e');
      }

      if (isBlocked) {
        log('[PhoneStateController] Call from $normalizedNumber is BLOCKED.');
        _rejectedNumber = normalizedNumber;
        try {
          log('[PhoneStateController] Attempting to reject call...');
          await NativeMethods.rejectCall();
          log('[PhoneStateController] Reject call command sent.');
        } catch (e) {
          log('[PhoneStateController] Error rejecting call: $e');
        }
        return;
      }
      log('[PhoneStateController] Call from $normalizedNumber is NOT blocked.');
    }

    final String callerName = '';

    CallState newState = CallState.idle;
    String stateMethod = '';

    switch (status) {
      case PhoneStateStatus.NOTHING:
        newState = CallState.idle;
        stateMethod = 'onCallEnded';
        break;
      case PhoneStateStatus.CALL_INCOMING:
        newState = CallState.incoming;
        stateMethod = 'onIncomingNumber';
        break;
      case PhoneStateStatus.CALL_STARTED:
        newState = CallState.active;
        stateMethod = 'onCall';
        break;
      case PhoneStateStatus.CALL_ENDED:
        newState = CallState.ended;
        stateMethod = 'onCallEnded';
        break;
    }

    if (stateMethod.isNotEmpty) {
      notifyServiceCallState(
        stateMethod,
        normalizedNumber,
        callerName,
        connected: isConnected,
        reason: reason ?? (newState == CallState.ended ? 'missed' : ''),
      );
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
      'callerName': callerName,
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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // _syncInitialCallState();
    }
  }

  Future<void> syncInitialCallState() async {
    log('[PhoneStateController] Syncing initial call state...');
    // ... 내부 로직 동일 ...
  }
}
