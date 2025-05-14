// lib/controllers/app_controller.dart
import 'dart:convert';
import 'dart:developer';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:mobile/controllers/blocked_numbers_controller.dart';
import 'package:mobile/controllers/call_log_controller.dart';
import 'package:mobile/controllers/contacts_controller.dart';
import 'package:mobile/controllers/permission_controller.dart';
import 'package:mobile/controllers/phone_state_controller.dart';
import 'package:mobile/controllers/sms_controller.dart';
import 'package:mobile/controllers/update_controller.dart';
import 'package:mobile/repositories/notification_repository.dart';
import 'package:mobile/services/app_background_service.dart';
import 'package:mobile/services/local_notification_service.dart';
import 'package:mobile/utils/constants.dart';
import 'package:mobile/utils/app_event_bus.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:mobile/services/native_default_dialer_methods.dart';
import 'package:mobile/services/native_methods.dart';
import 'package:permission_handler/permission_handler.dart';

// <<< 포그라운드 서비스 알림 ID 상수 추가 >>>
const int FOREGROUND_SERVICE_NOTIFICATION_ID = 777;

class AppController with ChangeNotifier {
  PhoneStateController? _phoneStateController;
  final ContactsController contactsController;
  final CallLogController callLogController;
  SmsController? _smsController;
  final BlockedNumbersController blockedNumbersController;
  final NotificationRepository _notificationRepository;

  // 로딩 상태 관리
  final _isInitializing = ValueNotifier<bool>(false);
  bool get isInitializing => _isInitializing.value;
  ValueNotifier<bool> get isInitializingNotifier => _isInitializing;
  String _initializationMessage = '';
  String get initializationMessage => _initializationMessage;

  // 초기화 상태
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  final ValueNotifier<bool> _isCoreInitializing = ValueNotifier(false);
  ValueNotifier<bool> get isCoreInitializing => _isCoreInitializing;
  String _coreInitMessage = '';
  String get coreInitMessage => _coreInitMessage;

  // 초기 사용자 데이터 로딩 상태를 위한 ValueNotifier 추가
  final ValueNotifier<bool> _isInitialUserDataLoading = ValueNotifier(false);
  ValueNotifier<bool> get isInitialUserDataLoadingNotifier =>
      _isInitialUserDataLoading;
  bool get isInitialUserDataLoading => _isInitialUserDataLoading.value;

  SmsController? get smsController => _smsController;
  PhoneStateController? get phoneStateController => _phoneStateController;

  AppController(
    PhoneStateController? phoneStateController,
    this.contactsController,
    this.callLogController,
    SmsController? smsController,
    this.blockedNumbersController,
    this._notificationRepository,
  ) : _phoneStateController = phoneStateController,
      _smsController = smsController {
    log('[AppController.constructor] Instance created.');
  }

  Future<bool> checkEssentialPermissions() async {
    log('[AppController.checkEssentialPermissions] Started.');
    final result = await PermissionController.requestAllEssentialPermissions();
    log('[AppController.checkEssentialPermissions] Finished. Result: $result');
    return result;
  }

  Future<void> initializeApp() async {
    log('[AppController.initializeApp] Started.');
    if (_isInitialized) {
      log('[AppController.initializeApp] Already pre-initialized, skipping...');
      return;
    }
    try {
      _initializationMessage = '전화 상태 감지 서비스 시작 중...';
      log('[AppController.initializeApp] Starting phone state listening...');
      if (_phoneStateController != null) {
        _phoneStateController!.startListening();
        log('[AppController.initializeApp] Phone state listening started.');
      } else {
        log(
          '[AppController.initializeApp] PhoneStateController is null, cannot start listening.',
        );
      }

      _initializationMessage = '알림 서비스 초기화 중...';
      log('[AppController.initializeApp] Initializing local notifications...');
      await LocalNotificationService.initialize();
      log('[AppController.initializeApp] Local notifications initialized.');

      _initializationMessage = '백그라운드 서비스 설정 중...';
      log('[AppController.initializeApp] Configuring background service...');
      await configureBackgroundService();
      log('[AppController.initializeApp] Background service configured.');

      _isInitialized = true;
      log(
        '[AppController.initializeApp] Pre-login initialization complete flag set.',
      );
    } catch (e, st) {
      log('[AppController.initializeApp] Error: $e\n$st');
      _isInitialized = false;
    }
    log('[AppController.initializeApp] Finished.');
  }

  Future<void> checkUpdate() async {
    log('[AppController.checkUpdate] Started.');
    try {
      final UpdateController updateController = UpdateController();
      final ver = await updateController.getServerVersion();
      log(
        '[AppController.checkUpdate] Server version: $ver, App version: $APP_VERSION',
      );
      if (ver.isNotEmpty && ver != APP_VERSION) {
        log(
          '[AppController.checkUpdate] Update available, attempting download and install...',
        );
        updateController.downloadAndInstallApk();
      } else {
        log(
          '[AppController.checkUpdate] App is up to date or server version not found.',
        );
      }
    } catch (e) {
      log('[AppController.checkUpdate] Error: $e');
    }
    log('[AppController.checkUpdate] Finished.');
  }

  Future<void> cleanupOnLogout() async {
    log('[AppController.cleanupOnLogout] Started.');
    await stopBackgroundService();
    if (_phoneStateController != null) {
      _phoneStateController!.stopListening();
    }
    await LocalNotificationService.cancelAllNotifications();
    if (_smsController != null) {
      await _smsController!.stopSmsObservationAndDispose();
      log(
        '[AppController.cleanupOnLogout] SMS observation stopped and listener disposed.',
      );
    } else {
      log(
        '[AppController.cleanupOnLogout] SmsController was null, skipping its cleanup.',
      );
    }
    log('[AppController.cleanupOnLogout] Finished.');
  }

  /// flutter_background_service config
  Future<void> configureBackgroundService() async {
    log('[AppController.configureBackgroundService] Started.');
    final service = FlutterBackgroundService();

    // 알림 저장 이벤트 처리
    service.on('saveNotification').listen((event) async {
      log(
        '[AppController.configureBackgroundService] Received saveNotification event: $event',
      );
      final id = event?['id'] as String? ?? '';
      final title = event?['title'] as String? ?? '';
      final message = event?['message'] as String? ?? '';
      final validUntil = event?['validUntil'] as String?;

      if (id.isNotEmpty) {
        await saveNotification(
          id: id,
          title: title,
          message: message,
          validUntil: validUntil,
        );
      }
    });

    // 만료된 알림 제거 이벤트 처리
    service.on('removeExpiredNotifications').listen((event) async {
      log(
        '[AppController.configureBackgroundService] Received removeExpiredNotifications event.',
      );
      await removeExpiredNotifications();
    });

    // <<< 기본 전화 앱 상태 요청 처리 리스너 추가 >>>
    service.on('requestDefaultDialerStatus').listen((event) async {
      log(
        '[AppController.configureBackgroundService] Received requestDefaultDialerStatus from background.',
      );
      try {
        final bool isDefault =
            await NativeDefaultDialerMethods.isDefaultDialer();
        log(
          '[AppController.configureBackgroundService] Checked isDefaultDialer status: $isDefault',
        );
        // 백그라운드로 결과 응답 보내기
        service.invoke('respondDefaultDialerStatus', {'isDefault': isDefault});
        log(
          '[AppController.configureBackgroundService] Sent respondDefaultDialerStatus to background.',
        );
      } catch (e) {
        log(
          '[AppController.configureBackgroundService] Error handling requestDefaultDialerStatus: $e',
        );
        // 오류 발생 시에도 응답은 보내주는 것이 좋음 (예: 기본값 false)
        service.invoke('respondDefaultDialerStatus', {
          'isDefault': false,
          'error': e.toString(),
        });
      }
    });
    // <<< 리스너 추가 끝 >>>

    // <<< 현재 통화 상태 요청 처리 리스너 추가 (타이머용) >>>
    service.on('requestCurrentCallStateFromAppControllerForTimer').listen((
      event,
    ) async {
      log(
        '[AppController.configureBackgroundService] Received requestCurrentCallStateFromAppControllerForTimer from background service.',
      );
      try {
        final Map<String, dynamic> nativeCallDetails =
            await NativeMethods.getCurrentCallState();
        service.invoke(
          'responseCurrentCallStateToBackgroundForTimer',
          nativeCallDetails,
        );
        log(
          '[AppController.configureBackgroundService] Sent responseCurrentCallStateToBackgroundForTimer with: $nativeCallDetails',
        );
      } catch (e) {
        log(
          '[AppController.configureBackgroundService] Error handling requestCurrentCallStateFromAppControllerForTimer: $e',
        );
        // 오류 발생 시에도 응답은 보내주는 것이 좋음 (예: 기본값 또는 에러 상태)
        service.invoke('responseCurrentCallStateToBackgroundForTimer', {
          'state': 'ERROR_FETCHING_NATIVE_TIMER', // 구체적인 에러 상태
          'number': null,
          'error': e.toString(),
        });
      }
    });
    // <<< 타이머용 리스너 추가 끝 >>>

    // 안드로이드/iOS 설정
    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStartOnBoot: false,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: 'jumo_foreground_service_channel',
        foregroundServiceNotificationId: FOREGROUND_SERVICE_NOTIFICATION_ID,
      ),
      iosConfiguration: IosConfiguration(autoStart: false),
    );
    log('[AppController.configureBackgroundService] Finished.');
  }

  Future<List<Map<String, dynamic>>> getNotifications() async {
    log('[AppController.getNotifications] Called.');
    return await _notificationRepository.getAllNotifications();
  }

  Future<void> removeExpiredNotifications() async {
    log('[AppController.removeExpiredNotifications] Started.');
    final removedCount =
        await _notificationRepository.removeExpiredNotifications();
    if (removedCount > 0) {
      appEventBus.fire(NotificationCountUpdatedEvent());
    }
    log(
      '[AppController.removeExpiredNotifications] Finished. Removed $removedCount notifications.',
    );
  }

  Future<void> saveNotification({
    required String id,
    required String title,
    required String message,
    String? validUntil,
  }) async {
    log('[AppController.saveNotification] Started for id: $id, title: $title');
    final isDisplayed = await _notificationRepository.isNotificationDisplayed(
      title,
      message,
    );
    final notifications = await _notificationRepository.getAllNotifications();
    final isDuplicate = notifications.any(
      (noti) => noti['title'] == title && noti['message'] == message,
    );

    if (!isDuplicate) {
      final newNotification = {
        'id': id,
        'title': title,
        'message': message,
        'timestamp': DateTime.now().toIso8601String(),
        'validUntil': validUntil,
      };
      await _notificationRepository.saveNotification(newNotification);
      log('[AppController.saveNotification] New notification saved.');
      appEventBus.fire(NotificationCountUpdatedEvent());
    }

    if (!isDisplayed) {
      await LocalNotificationService.showNotification(
        id: notifications.length, // ID를 현재 알림 수로 사용하는 것은 중복될 수 있음. 고유 ID 사용 고려.
        title: title,
        body: message,
      );
      log('[AppController.saveNotification] Notification displayed locally.');
      await _notificationRepository.markNotificationAsDisplayed(title, message);
    }
    log('[AppController.saveNotification] Finished.');
  }

  Future<void> startBackgroundService() async {
    log('[AppController.startBackgroundService] Started.');
    final service = FlutterBackgroundService();
    if (await service.isRunning()) {
      log(
        '[AppController.startBackgroundService] Background service already running! Skipping start.',
      );
      return;
    }
    try {
      await service.startService();
      log(
        '[AppController.startBackgroundService] Background service started successfully via service.startService().',
      );
    } catch (e) {
      log(
        '[AppController.startBackgroundService] Error starting background service: $e',
      );
    }
    log('[AppController.startBackgroundService] Finished.');
  }

  Future<void> stopBackgroundService() async {
    log('[AppController.stopBackgroundService] Started.');
    final service = FlutterBackgroundService();
    if (!(await service.isRunning())) {
      log(
        '[AppController.stopBackgroundService] Background service not running! Skipping stop.',
      );
      return;
    }
    try {
      service.invoke('stopService');
      log(
        '[AppController.stopBackgroundService] Sent stop command to background service.',
      );
    } catch (e) {
      log(
        '[AppController.stopBackgroundService] Error sending stop command: $e',
      );
    }
    log('[AppController.stopBackgroundService] Finished.');
  }

  // <<< 새로운 핵심 데이터 및 서비스 초기화 함수 >>>
  Future<void> performCoreInitialization() async {
    if (_isCoreInitializing.value) {
      log(
        '[AppController.performCoreInitialization] Already in progress. Skipping.',
      );
      return;
    }
    log('[AppController.performCoreInitialization] Started.');
    final stopwatch = Stopwatch()..start();
    _isCoreInitializing.value = true;
    notifyListeners();
    _coreInitMessage = '초기 설정 로딩 중...';

    try {
      _coreInitMessage = '차단 설정 로딩 중...';
      log(
        '[AppController.performCoreInitialization] Step 1 (was 2): Initializing blocked numbers (local)...',
      );
      await blockedNumbersController.initialize();
      log(
        '[AppController.performCoreInitialization] Step 1 (was 2): Blocked numbers initialized.',
      );

      _coreInitMessage = '백그라운드 서비스 시작 중...';
      log(
        '[AppController.performCoreInitialization] Step 2 (was 3): Starting background service...',
      );
      await startBackgroundService();
      log(
        '[AppController.performCoreInitialization] Step 2 (was 3): Background service start requested.',
      );

      _coreInitMessage = '백그라운드 작업 요청 중...';
      log(
        '[AppController.performCoreInitialization] Step 3 (was 4): Requesting initial background tasks (delay 2s)...',
      );
      final service = FlutterBackgroundService();
      await Future.delayed(const Duration(seconds: 2));
      if (await service.isRunning()) {
        log(
          '[AppController.performCoreInitialization] Step 3.1 (was 4.1): Service is running. Invoking tasks: syncBlockedListsNow...',
        );
        try {
          service.invoke('syncBlockedListsNow');
          log(
            '[AppController.performCoreInitialization] Step 3.1 (was 4.1): Successfully invoked background tasks.',
          );
        } catch (e) {
          log(
            '[AppController.performCoreInitialization] Step 3.1 (was 4.1): Error invoking background tasks: $e',
          );
        }
      } else {
        log(
          '[AppController.performCoreInitialization] Step 3.1 (was 4.1): Background service is NOT running after start request. Cannot invoke tasks.',
        );
      }
      log(
        '[AppController.performCoreInitialization] Step 3 (was 4): Initial background tasks request finished.',
      );

      _coreInitMessage = '핵심 초기화 완료';
      log(
        '[AppController.performCoreInitialization] All core (non-user-data) steps complete.',
      );
    } catch (e, st) {
      _coreInitMessage = '핵심 초기화 중 오류 발생';
      log(
        '[AppController.performCoreInitialization] Error during core initialization: $e\n$st',
      );
    } finally {
      _isCoreInitializing.value = false;
      notifyListeners();
      stopwatch.stop();
      log(
        '[AppController.performCoreInitialization] Finished. Total time: ${stopwatch.elapsedMilliseconds}ms',
      );
    }
  }

  Future<void> triggerContactsLoadIfReady() async {
    log('[AppController.triggerContactsLoadIfReady] Started.');
    if (_isInitialUserDataLoading.value) {
      log(
        '[AppController.triggerContactsLoadIfReady] Already loading initial user data. Skipping.',
      );
      return;
    }
    _isInitialUserDataLoading.value = true;
    notifyListeners();

    bool contactsChanged = false;
    bool callLogChanged = false;
    bool smsLogChanged = false;

    try {
      log(
        '[AppController.triggerContactsLoadIfReady] Step 1: Loading contacts...',
      );
      if (contactsController.isSyncing) {
        log(
          '[AppController.triggerContactsLoadIfReady] Contacts are already syncing. Skipping contact load trigger.',
        );
      } else if (contactsController.initialLoadAttempted) {
        log(
          '[AppController.triggerContactsLoadIfReady] Contacts initial load was already attempted. Triggering a non-forced refresh for contacts.',
        );
        await contactsController.syncContacts();
      } else {
        log(
          '[AppController.triggerContactsLoadIfReady] Triggering initial contacts load via ContactsController.',
        );
        await contactsController.syncContacts();
      }
      log(
        '[AppController.triggerContactsLoadIfReady] Step 1: Contacts loading process finished.',
      );

      log(
        '[AppController.triggerContactsLoadIfReady] Step 2: Loading call logs...',
      );
      callLogChanged = await callLogController.refreshCallLogs();
      log(
        '[AppController.triggerContactsLoadIfReady] Step 2: Call logs loaded/refreshed. Changed: $callLogChanged',
      );

      log(
        '[AppController.triggerContactsLoadIfReady] Step 3: Initializing SMS features and loading SMS logs...',
      );
      if (_smsController == null) {
        log(
          '[AppController.triggerContactsLoadIfReady] SmsController is null, skipping SMS features.',
        );
      } else {
        final smsPermissionStatus = await Permission.sms.status;
        if (smsPermissionStatus.isGranted) {
          log(
            '[AppController.triggerContactsLoadIfReady] SMS permission granted. Initializing SMS features...',
          );
          await _smsController!.startSmsObservation();
          _smsController!.listenToSmsEvents();
          smsLogChanged = await _smsController!.refreshSms();
          log(
            '[AppController.triggerContactsLoadIfReady] Step 3: SMS features initialized and logs loaded/refreshed. Changed: $smsLogChanged',
          );
        } else {
          log(
            '[AppController.triggerContactsLoadIfReady] SMS permission not granted. SMS features will not be initialized.',
          );
        }
      }
    } catch (e, st) {
      log(
        '[AppController.triggerContactsLoadIfReady] Error loading initial user data: $e\n$st',
      );
    } finally {
      _isInitialUserDataLoading.value = false;
      log(
        '[AppController.triggerContactsLoadIfReady] Finished loading all initial user data. ContactsChanged (assumed): N/A, CallLogChanged: $callLogChanged, SmsLogChanged: $smsLogChanged',
      );
      notifyListeners();
    }
  }

  // UI 업데이트 요청을 위한 메소드
  void requestUiUpdate({String source = 'Unknown'}) {
    log('[AppController.requestUiUpdate] UI update requested from: $source');
    notifyListeners();
  }

  // SmsController를 나중에 설정하기 위한 메소드
  void setSmsController(SmsController controller) {
    log('[AppController.setSmsController] SmsController has been set.');
    _smsController = controller;
  }

  void setPhoneStateController(PhoneStateController controller) {
    log(
      '[AppController.setPhoneStateController] PhoneStateController has been set.',
    );
    _phoneStateController = controller;
  }
}

// iOS 백그라운드 핸들러 (필요 시 구현)
@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  log('[onIosBackground] FLUTTER BACKGROUND FETCH (iOS).');
  return true;
}
