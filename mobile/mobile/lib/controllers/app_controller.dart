// lib/controllers/app_controller.dart
import 'dart:convert';
import 'dart:developer';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:hive_ce/hive.dart';
import 'package:mobile/controllers/blocked_numbers_controller.dart';
import 'package:mobile/controllers/call_log_controller.dart';
import 'package:mobile/controllers/contacts_controller.dart';
import 'package:mobile/controllers/permission_controller.dart';
import 'package:mobile/controllers/phone_state_controller.dart';
import 'package:mobile/controllers/sms_controller.dart';
import 'package:mobile/controllers/update_controller.dart';
import 'package:mobile/services/app_background_service.dart';
import 'package:mobile/services/local_notification_service.dart';
import 'package:mobile/utils/constants.dart';
import 'package:mobile/utils/app_event_bus.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:mobile/services/native_default_dialer_methods.dart';

// <<< 포그라운드 서비스 알림 ID 상수 추가 >>>
const int FOREGROUND_SERVICE_NOTIFICATION_ID = 777;

class AppController {
  final PhoneStateController phoneStateController;
  final ContactsController contactsController;
  final CallLogController callLogController;
  final SmsController smsController;
  final BlockedNumbersController blockedNumbersController;
  Box get _settingsBox => Hive.box('settings');
  Box get _notificationsBox => Hive.box('notifications');
  Box get _displayNotiIdsBox => Hive.box('display_noti_ids');

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
  );

  Future<bool> checkEssentialPermissions() async {
    log('[AppController] Checking essential permissions...');
    final result = await PermissionController.requestAllEssentialPermissions();
    log('[AppController] Permission check result: $result');
    return result;
  }

  Future<void> initializeApp() async {
    log('[AppController] Performing pre-login initialization...');
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

  List<Map<String, dynamic>> getNotifications() {
    final notifications = _notificationsBox.values.toList();
    try {
      return notifications.cast<Map<String, dynamic>>().toList();
    } catch (e) {
      log('[AppController] Error casting notifications from Hive: $e');
      return [];
    }
  }

  // 만료된 알림 제거
  Future<void> removeExpiredNotifications() async {
    final notifications = getNotifications();
    final now = DateTime.now().toUtc();
    final validNotifications =
        notifications.where((notification) {
          final validUntilStr = notification['validUntil'] as String?;
          if (validUntilStr == null) return true;
          try {
            final validUntil = DateTime.parse(validUntilStr).toUtc();
            return validUntil.isAfter(now);
          } catch (e) {
            log("Error parsing validUntil date: $validUntilStr");
            return true;
          }
        }).toList();

    if (validNotifications.length != notifications.length) {
      log(
        '[AppController] Removing ${notifications.length - validNotifications.length} expired notifications.',
      );
      await _notificationsBox.clear();
      await _notificationsBox.addAll(validNotifications);
      appEventBus.fire(NotificationCountUpdatedEvent());
    }
  }

  // 알림 저장 (내부 로직)
  Future<void> saveNotification({
    required String id,
    required String title,
    required String message,
    String? validUntil,
  }) async {
    // 표시된 알림 ID 로드 (JSON 문자열 리스트 저장 방식으로 변경)
    final displayedListRaw =
        _displayNotiIdsBox.get('ids', defaultValue: '[]') as String;
    List<Map<String, dynamic>> displayedNotiIds;
    try {
      displayedNotiIds =
          (jsonDecode(displayedListRaw) as List).cast<Map<String, dynamic>>();
    } catch (_) {
      displayedNotiIds = [];
    }

    final isDisplayed = displayedNotiIds.any(
      (noti) => noti['title'] == title && noti['message'] == message,
    );

    // 기존 알림 로드 (getNotifications 사용)
    final notifications = getNotifications();
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
      await _notificationsBox.put(id, newNotification);

      appEventBus.fire(NotificationCountUpdatedEvent());
    }

    if (!isDisplayed) {
      await LocalNotificationService.showNotification(
        id: notifications.length,
        title: title,
        body: message,
      );
      displayedNotiIds.add({'title': title, 'message': message});
      await _displayNotiIdsBox.put('ids', jsonEncode(displayedNotiIds));
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
      await Future.delayed(const Duration(seconds: 2));
      if (await service.isRunning()) {
        log(
          '[AppController] Service is running. Invoking tasks: uploadCallLogsNow, startContactSyncNow, syncBlockedListsNow...',
        );
        try {
          service.invoke('uploadCallLogsNow');
          service.invoke('startContactSyncNow');
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

      // 4. 앱 업데이트 확인 등 추가 작업 (필요 시)

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
}

// iOS 백그라운드 핸들러 (필요 시 구현)
@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  log('FLUTTER BACKGROUND FETCH');
  // 필요한 백그라운드 작업 수행 (예: 알림 확인 등)
  return true;
}
