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

  AppController(
    this.phoneStateController,
    this.contactsController,
    this.callLogController,
    this.smsController,
    this.blockedNumbersController,
  );

  Future<bool> checkEssentialPermissions() async {
    return await PermissionController.requestAllEssentialPermissions();
  }

  Future<void> initializeApp() async {
    // 로그인 불필요한 초기화만 수행
    log('[AppController] Performing pre-login initialization...');
    if (_isInitialized) {
      log('[AppController] Already pre-initialized, skipping...');
      return;
    }
    try {
      // 1. 전화 상태 감지 시작
      _initializationMessage = '전화 상태 감지 서비스 시작 중...';
      phoneStateController.startListening();

      // 2. 로컬 알림 초기화
      _initializationMessage = '알림 서비스 초기화 중...';
      await LocalNotificationService.initialize();

      // 3. 백그라운드 서비스 설정 (시작은 로그인 후)
      _initializationMessage = '백그라운드 서비스 설정 중...';
      await configureBackgroundService();

      // 4. 네이티브 앱 초기화 완료 알림 (HomeScreen에서 호출)
      // log('[AppController] Notifying native app initialized...');
      // await NativeDefaultDialerMethods.notifyNativeAppInitialized();

      // 5. 앱 업데이트 확인 (선택적 - 로그인 전 실행 가능)
      _initializationMessage = '앱 업데이트 확인 중...';
      // await checkUpdate(); // 로그인 후 또는 다른 시점으로 이동 고려

      _isInitialized = true;
      log('[AppController] Pre-login initialization complete.');
    } catch (e) {
      log('[AppController] Error during pre-login initialization: $e');
    } finally {
      // _isInitializing.value = false; // 제거
    }

    // --- 아래 로직은 로그인 *후* HomeScreen 등에서 별도 호출 ---
    // await blockedNumbersController.initialize();
    // await callLogController.refreshCallLogs();
    // await smsController.refreshSms();
    // final service = FlutterBackgroundService();
    // if (await service.isRunning()) {
    //   service.invoke('startContactSyncNow');
    // }
  }

  Future<void> checkUpdate() async {
    log('check Update');
    final UpdateController updateController = UpdateController();

    final ver = await updateController.getServerVersion();

    if (ver.isNotEmpty && ver != APP_VERSION) {
      updateController.downloadAndInstallApk();
    }
  }

  Future<void> cleanupOnLogout() async {
    // 백그라운드 서비스 정지
    await stopBackgroundService();

    // 전화 상태 감지 중지
    phoneStateController.stopListening();

    // 로컬 알림 정리
    await LocalNotificationService.cancelAllNotifications();
  }

  /// flutter_background_service config
  Future<void> configureBackgroundService() async {
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

    // 통화 UI 업데이트 이벤트 리스너 제거
    // service.on('updateCallUI').listen((event) {
    //    // TODO: 통화 중 화면에 시간 업데이트 등 이벤트 전달
    // });

    // 안드로이드/iOS 설정
    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStartOnBoot: false,
        autoStart: false,
        isForegroundMode: false,
        notificationChannelId: 'jumo_data_sync_channel',
        initialNotificationTitle: 'JUMO 서비스',
        initialNotificationContent: '데이터 동기화 및 통화 서비스 실행 중',
      ),
      iosConfiguration: IosConfiguration(autoStart: false),
    );
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
    final service = FlutterBackgroundService();
    if (await service.isRunning()) {
      log('[AppController] Background service already running!');
      return;
    }
    await service.startService();
    log('[AppController] Background service started.');
  }

  Future<void> stopBackgroundService() async {
    final service = FlutterBackgroundService();
    if (!(await service.isRunning())) {
      log('[AppController] Background service not running!');
      return;
    }
    service.invoke('stopService');
    log('[AppController] Sent stop command to background service.');
  }

  // 로그인 후 데이터 로딩/초기화 함수
  Future<void> initializePostLoginData() async {
    log('[AppController] Initializing post-login data...');
    _isInitializing.value = true;
    try {
      // **** 백그라운드 서비스 시작 (로그인 후) ****
      await startBackgroundService();

      _initializationMessage = '차단 목록 동기화 중...';
      await blockedNumbersController.initialize();

      _initializationMessage = '통화 기록 동기화 중...';
      await callLogController.refreshCallLogs();

      _initializationMessage = 'SMS 기록 동기화 중...';
      await smsController.refreshSms();

      // 백그라운드 연락처 동기화 즉시 요청
      final service = FlutterBackgroundService();
      if (await service.isRunning()) {
        log('[AppController] Invoking initial contact sync post-login...');
        service.invoke('startContactSyncNow');
      }

      // 앱 업데이트 확인 (로그인 후 실행)
      await checkUpdate();

      log('[AppController] Post-login data initialization complete.');
    } catch (e) {
      log('[AppController] Error initializing post-login data: $e');
    } finally {
      _isInitializing.value = false;
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
