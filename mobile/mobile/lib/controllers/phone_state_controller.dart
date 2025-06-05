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
import 'package:mobile/controllers/app_controller.dart';
import 'package:mobile/utils/app_event_bus.dart';

class PhoneStateController with WidgetsBindingObserver {
  final GlobalKey<NavigatorState> navigatorKey;
  final CallLogController callLogController;
  final ContactsController contactsController;
  final BlockedNumbersController _blockedNumbersController;
  final AppController appController;

  PhoneStateController(
    this.navigatorKey,
    this.callLogController,
    this.contactsController,
    this._blockedNumbersController,
    this.appController,
  ) {
    WidgetsBinding.instance.addObserver(this);
    log('[PhoneStateController.constructor] Instance created.');

    final service = FlutterBackgroundService();
    _searchResetSubscription = service.on('requestSearchDataReset').listen((
      event,
    ) {
      log('[PhoneStateController][CRITICAL] 검색 데이터 리셋 요청 수신');
      appEventBus.fire(CallSearchResetEvent(''));
    });
  }

  StreamSubscription<PhoneState>? _phoneStateSubscription;
  StreamSubscription? _searchResetSubscription;

  String? _lastProcessedNumber;
  PhoneStateStatus? _lastProcessedStatus;
  DateTime? _lastProcessedTime;
  String? _rejectedNumber;

  void startListening() {
    _phoneStateSubscription?.cancel();
    _phoneStateSubscription = PhoneState.stream.listen((event) async {
      // log(
      //   '[PhoneStateController][Stream] Received event: ${event.status}, Number: ${event.number}',
      // );
      final isDef = await NativeDefaultDialerMethods.isDefaultDialer();
      if (!isDef) {
        await _handlePhoneStateEvent(event.status, event.number);
      } else {
        // log(
        //   '[PhoneStateController][Stream] Default dialer is active, ignoring event from phone_state package.',
        // );
      }
    });
    log(
      '[PhoneStateController.startListening] Listening to phone state stream.',
    );
  }

  void stopListening() {
    _phoneStateSubscription?.cancel();
    _phoneStateSubscription = null;
    _searchResetSubscription?.cancel();
    _searchResetSubscription = null;
    log('[PhoneStateController] Stopped listening to phone state stream.');
  }

  Future<void> handleNativeEvent(
    String method,
    dynamic args,
    bool isDefault,
  ) async {
    log(
      '[PhoneStateController][Native] Received event: $method, IsDefault: $isDefault',
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
        if (number.isNotEmpty) {
          log(
            '[PhoneStateController][CRITICAL] 네이티브에서 인코밍 콜 감지: $number - 데이터 초기화 요청',
          );
          appEventBus.fire(CallSearchResetEvent(number));
        }
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
    // log('[_isDuplicateEvent] Checking: number=$number, status=$status');
    // log(
    //   '[_isDuplicateEvent] Last processed: number=$_lastProcessedNumber, status=$_lastProcessedStatus, time=$_lastProcessedTime',
    // );

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
      // log('[_isDuplicateEvent] Updated last processed info.');
    } else {
      log(
        '[_isDuplicateEvent] Duplicate event detected and ignored: num=$number, status=$status',
      );
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
      // log(
      //   '[_handlePhoneStateEvent] Duplicate event ignored. Number: $number, Status: $status',
      // );
      return;
    }
    log(
      '[_handlePhoneStateEvent] Processing event. Number: $number, Status: $status, Reason: $reason',
    );

    String? normalizedNumber;
    if (number != null && number.isNotEmpty) {
      normalizedNumber = normalizePhone(number);
    } else {
      if (status == PhoneStateStatus.CALL_ENDED && _rejectedNumber != null) {
        // log(
        //   '[_handlePhoneStateEvent] Ignoring CALL_ENDED event with null number, possibly after rejection.',
        // );
        _rejectedNumber = null;
        return;
      }
      if (status == PhoneStateStatus.NOTHING ||
          status == PhoneStateStatus.CALL_ENDED) {
        // log(
        //   '[_handlePhoneStateEvent] Number is null or empty for status $status, processing as general state change.',
        // );
        if (status == PhoneStateStatus.CALL_ENDED) {
          // log('[_handlePhoneStateEvent] Call ended (null number). Adding 1.5s delay before refreshing call logs.');
          await Future.delayed(const Duration(milliseconds: 1500));
          bool callLogChanged = await callLogController.refreshCallLogs();
          if (callLogChanged) {
            // log(
            //   '[_handlePhoneStateEvent] Call logs changed (null number end), firing CallLogUpdatedEvent.',
            // );
            appEventBus.fire(CallLogUpdatedEvent());
          }
        }
        return;
      }
      log(
        '[_handlePhoneStateEvent] Number is null for critical state $status. Ignoring.',
      );
      return;
    }

    if (status == PhoneStateStatus.CALL_ENDED &&
        _rejectedNumber == normalizedNumber) {
      log(
        '[_handlePhoneStateEvent] Ignoring CALL_ENDED for recently REJECTED: $normalizedNumber',
      );
      _rejectedNumber = null;
      return;
    }
    if (status != PhoneStateStatus.CALL_ENDED) {
      _rejectedNumber = null;
    }

    if (status == PhoneStateStatus.CALL_INCOMING) {
      // log(
      //   '[PhoneStateController] Checking block status for incoming call: $normalizedNumber',
      // );
      bool isBlocked = false;
      try {
        isBlocked = await _blockedNumbersController.isNumberBlockedAsync(
          normalizedNumber!,
          addHistory: true,
        );
      } catch (e) {
        log('[PhoneStateController] Error checking block status: $e');
      }

      if (isBlocked) {
        log('[PhoneStateController] Call from $normalizedNumber is BLOCKED.');
        _rejectedNumber = normalizedNumber;
        try {
          // log('[PhoneStateController] Attempting to reject call...');
          await NativeMethods.rejectCall();
          // log('[PhoneStateController] Reject call command sent.');
        } catch (e) {
          log('[PhoneStateController] Error rejecting call: $e');
        }
        return;
      }
      // log('[PhoneStateController] Call from $normalizedNumber is NOT blocked.');
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
        normalizedNumber!,
        callerName,
        connected: isConnected,
        reason: reason ?? (newState == CallState.ended ? 'missed' : ''),
      );
    }

    if (status == PhoneStateStatus.CALL_ENDED) {
      // log('[_handlePhoneStateEvent] Call ended. Adding 1.5s delay before refreshing call logs.');
      await Future.delayed(const Duration(milliseconds: 1500));
      bool callLogChanged = await callLogController.refreshCallLogs();
      if (callLogChanged) {
        log(
          '[_handlePhoneStateEvent] Call logs changed, firing CallLogUpdatedEvent.',
        );
        appEventBus.fire(CallLogUpdatedEvent());
      }
    }
  }

  void notifyServiceCallState(
    String stateMethod,
    String number,
    String callerName, {
    bool? connected,
    String? reason,
  }) {
    // log(
    //   '[PhoneStateController][notifyServiceCallState] Method called: stateMethod=$stateMethod, number=$number, name=$callerName, connected=$connected, reason=$reason',
    // );

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
      // log(
      //   '[PhoneStateController][notifyServiceCallState] Unknown stateMethod $stateMethod, not invoking service.',
      // );
      return;
    }

    final payload = {
      'state': state,
      'number': number,
      'callerName': callerName,
      'connected': isConnectedValue,
      'reason': reasonValue,
    };

    // log(
    //   '[PhoneStateController][notifyServiceCallState] Invoking service with callStateChanged. Payload: $payload',
    // );
    try {
      service.invoke('callStateChanged', payload);
      // log(
      //   '[PhoneStateController][notifyServiceCallState] Successfully invoked service with callStateChanged.',
      // );
    } catch (e) {
      log(
        '[PhoneStateController][notifyServiceCallState] Error invoking service: $e',
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // log('[PhoneStateController.didChangeAppLifecycleState] State: $state');
    if (state == AppLifecycleState.resumed) {
      // _syncInitialCallState();
    }
  }

  Future<void> syncInitialCallState() async {
    // log('[PhoneStateController] Syncing initial call state...');
    // ... 내부 로직 동일 ...
  }
}
