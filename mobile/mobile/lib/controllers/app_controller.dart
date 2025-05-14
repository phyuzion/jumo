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

class AppController {
  final PhoneStateController phoneStateController;
  final ContactsController contactsController;
  final CallLogController callLogController;
  final SmsController smsController;
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

  AppController(
    this.phoneStateController,
    this.contactsController,
    this.callLogController,
    this.smsController,
    this.blockedNumbersController,
    this._notificationRepository,
  );

  Future<bool> checkEssentialPermissions() async {
    log('[AppController] Checking essential permissions...');
    final result = await PermissionController.requestAllEssentialPermissions();
    log('[AppController] Permission check result: $result');
    return result;
  }

  Future<void> initializeApp() async {
    log(
      '[AppController] Performing pre-login initialization (initializeApp called)...',
    );
    if (_isInitialized) {
      log('[AppController] Already pre-initialized, skipping...');
      return;
    }
    try {
      _initializationMessage = '전화 상태 감지 서비스 시작 중...';
      phoneStateController.startListening();
      log('[AppController] Phone state listening started.');

      _initializationMessage = '알림 서비스 초기화 중...';
      await LocalNotificationService.initialize();
      log('[AppController] Local notifications initialized.');

      _initializationMessage = '백그라운드 서비스 설정 중...';
      await configureBackgroundService();
      log('[AppController] Background service configured.');

      _isInitialized = true;
      log('[AppController] Pre-login initialization complete flag set.');
    } catch (e, st) {
      log('[AppController] Error during pre-login initialization: $e\n$st');
      _isInitialized = false;
    }
    log('[AppController] initializeApp finished.');
  }

  Future<void> checkUpdate() async {
    log('[AppController] checkUpdate started.');
    try {
      final UpdateController updateController = UpdateController();
      final ver = await updateController.getServerVersion();
      log('[AppController] Server version: $ver, App version: $APP_VERSION');
      if (ver.isNotEmpty && ver != APP_VERSION) {
        log(
          '[AppController] Update available, attempting download and install...',
        );
        updateController.downloadAndInstallApk();
      } else {
        log('[AppController] App is up to date or server version not found.');
      }
    } catch (e) {
      log('[AppController] Error checking update: $e');
    }
  }

  Future<void> cleanupOnLogout() async {
    log('[AppController] cleanupOnLogout called.');
    await stopBackgroundService();
    phoneStateController.stopListening();
    await LocalNotificationService.cancelAllNotifications();
    await smsController.stopSmsObservationAndDispose();
    log('[AppController] SMS observation stopped and listener disposed.');
    log('[AppController] Cleanup on logout finished.');
  }

  /// flutter_background_service config
  Future<void> configureBackgroundService() async {
    log('[AppController] configureBackgroundService executing...');
    final service = FlutterBackgroundService();

    // 알림 저장 이벤트 처리
    service.on('saveNotification').listen((event) async {
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
      await removeExpiredNotifications();
    });

    // <<< 기본 전화 앱 상태 요청 처리 리스너 추가 >>>
    service.on('requestDefaultDialerStatus').listen((event) async {
      log(
        '[AppController] Received requestDefaultDialerStatus from background.',
      );
      try {
        final bool isDefault =
            await NativeDefaultDialerMethods.isDefaultDialer();
        log('[AppController] Checked isDefaultDialer status: $isDefault');
        // 백그라운드로 결과 응답 보내기
        service.invoke('respondDefaultDialerStatus', {'isDefault': isDefault});
        log('[AppController] Sent respondDefaultDialerStatus to background.');
      } catch (e) {
        log('[AppController] Error handling requestDefaultDialerStatus: $e');
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
        '[AppController] Received requestCurrentCallStateFromAppControllerForTimer from background service.',
      );
      try {
        final Map<String, dynamic> nativeCallDetails =
            await NativeMethods.getCurrentCallState();
        service.invoke(
          'responseCurrentCallStateToBackgroundForTimer',
          nativeCallDetails,
        );
        log(
          '[AppController] Sent responseCurrentCallStateToBackgroundForTimer with: $nativeCallDetails',
        );
      } catch (e) {
        log(
          '[AppController] Error handling requestCurrentCallStateFromAppControllerForTimer: $e',
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
    log('[AppController] Background service configuration complete.');
  }

  Future<List<Map<String, dynamic>>> getNotifications() async {
    return await _notificationRepository.getAllNotifications();
  }

  Future<void> removeExpiredNotifications() async {
    final removedCount =
        await _notificationRepository.removeExpiredNotifications();
    if (removedCount > 0) {
      appEventBus.fire(NotificationCountUpdatedEvent());
    }
  }

  Future<void> saveNotification({
    required String id,
    required String title,
    required String message,
    String? validUntil,
  }) async {
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
      appEventBus.fire(NotificationCountUpdatedEvent());
    }

    if (!isDisplayed) {
      await LocalNotificationService.showNotification(
        id: notifications.length,
        title: title,
        body: message,
      );
      await _notificationRepository.markNotificationAsDisplayed(title, message);
    }
  }

  Future<void> startBackgroundService() async {
    log('[AppController] startBackgroundService called.');
    final service = FlutterBackgroundService();
    if (await service.isRunning()) {
      log('[AppController] Background service already running!');
      return;
    }
    try {
      await service.startService();
      log('[AppController] Background service started successfully.');
    } catch (e) {
      log('[AppController] Error starting background service: $e');
    }
  }

  Future<void> stopBackgroundService() async {
    log('[AppController] stopBackgroundService called.');
    final service = FlutterBackgroundService();
    if (!(await service.isRunning())) {
      log('[AppController] Background service not running!');
      return;
    }
    try {
      service.invoke('stopService');
      log('[AppController] Sent stop command to background service.');
    } catch (e) {
      log('[AppController] Error sending stop command: $e');
    }
  }

  // <<< 새로운 핵심 데이터 및 서비스 초기화 함수 >>>
  Future<void> performCoreInitialization() async {
    if (_isCoreInitializing.value) {
      log('[AppController] Core initialization already in progress. Skipping.');
      return;
    }
    log('[AppController] Starting core data and service initialization...');
    final stopwatch = Stopwatch()..start();
    _isCoreInitializing.value = true;
    _coreInitMessage = '초기 설정 로딩 중...';

    try {
      // 1. 로컬 데이터 로딩 (HomeScreen에서 옮겨옴)
      _coreInitMessage = '통화 기록 로딩 중...';
      log(
        '[AppController] Refreshing call logs (local)... from performCoreInitialization',
      );
      await callLogController.refreshCallLogs();
      log('[AppController] Call logs refreshed.');

      _coreInitMessage = '차단 설정 로딩 중...';
      log(
        '[AppController] Initializing blocked numbers (local)... from performCoreInitialization',
      );
      await blockedNumbersController.initialize(); // 로컬 초기화
      log('[AppController] Blocked numbers initialized.');

      // 2. 백그라운드 서비스 시작
      _coreInitMessage = '백그라운드 서비스 시작 중...';
      log(
        '[AppController] Starting background service... from performCoreInitialization',
      );
      await startBackgroundService(); // 내부에서 isRunning 체크 함
      log('[AppController] Background service start requested.');

      // 3. 백그라운드 작업 요청 (서비스 시작 후)
      _coreInitMessage = '백그라운드 작업 요청 중...';
      log(
        '[AppController] Requesting initial background tasks... from performCoreInitialization',
      );
      final service = FlutterBackgroundService();
      await Future.delayed(const Duration(seconds: 2)); // 서비스 시작 대기
      if (await service.isRunning()) {
        log(
          '[AppController] Service is running. Invoking tasks: syncBlockedListsNow...',
        );
        try {
          // service.invoke('startContactSyncNow'); // 연락처 동기화는 main isolate에서만
          service.invoke('syncBlockedListsNow');
          log('[AppController] Successfully invoked background tasks.');
        } catch (e) {
          log('[AppController] Error invoking background tasks: $e');
        }
      } else {
        log(
          '[AppController] Background service is not running after start request. Cannot invoke tasks.',
        );
      }

      // SMS 기능 초기화 (READ_SMS 권한 확인 후)
      _coreInitMessage = 'SMS 기능 초기화 중...';
      log(
        '[AppController] Checking SMS permission for SMS feature initialization...',
      );
      final smsPermissionStatus = await Permission.sms.status;
      if (smsPermissionStatus.isGranted) {
        log(
          '[AppController] SMS permission granted. Initializing SMS features.',
        );
        await smsController.initializeSmsFeatures();
      } else {
        log(
          '[AppController] SMS permission not granted. SMS features will not be initialized at this time.',
        );
        // 권한이 없다면 DeciderScreen에서 요청하거나, 설정에서 사용자가 직접 켜야 함.
        // 여기서는 일단 로그만 남기고 넘어감.
      }

      _coreInitMessage = '초기화 완료';
      log('[AppController] Core data and service initialization complete.');
    } catch (e, st) {
      _coreInitMessage = '초기화 중 오류 발생';
      log(
        '[AppController] Error during core data and service initialization: $e\n$st',
      );
    } finally {
      _isCoreInitializing.value = false;
      stopwatch.stop();
      log(
        '[AppController] Total core data and service initialization took: ${stopwatch.elapsedMilliseconds}ms',
      );
    }
  }

  // <<< 연락처 로드를 트리거하는 새로운 메소드 >>>
  Future<void> triggerContactsLoadIfReady() async {
    if (contactsController.isSyncing) {
      log('[AppController] Contacts are already syncing. Skipping trigger.');
      return;
    }

    if (contactsController.initialLoadAttempted) {
      log(
        '[AppController] Contacts initial load was already attempted. Triggering a non-forced refresh for consistency.',
      );
      await contactsController.refreshContacts(force: false);
      return;
    }

    log(
      '[AppController] Triggering initial contacts load via ContactsController as conditions are assumed to be met.',
    );
    await contactsController.loadInitialContacts();
  }
}

// iOS 백그라운드 핸들러 (필요 시 구현)
@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  log('FLUTTER BACKGROUND FETCH');
  // 필요한 백그라운드 작업 수행 (예: 알림 확인 등)
  return true;
}
