// lib/controllers/app_controller.dart
import 'dart:developer';
import 'package:flutter_background_service/flutter_background_service.dart';
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
import 'package:get_storage/get_storage.dart';
import 'package:mobile/utils/app_event_bus.dart';
import 'dart:async';

class AppController {
  final PhoneStateController phoneStateController;
  final ContactsController contactsController;
  final CallLogController callLogController;
  final SmsController smsController;
  final BlockedNumbersController blockedNumbersController;
  final box = GetStorage();

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
    await checkUpdate();
    await initializeData();
    await LocalNotificationService.initialize();

    phoneStateController.startListening();
  }

  Future<void> checkUpdate() async {
    log('check Update');
    final UpdateController updateController = UpdateController();

    final ver = await updateController.getServerVersion();

    if (ver.isNotEmpty && ver != APP_VERSION) {
      updateController.downloadAndInstallApk();
    }
  }

  Future<void> initializeData() async {
    // 컨트롤러들(실제 diff 로직)

    await blockedNumbersController.initialize();
    await contactsController.syncContactsAll();
    await callLogController.refreshCallLogs();
    await smsController.refreshSms();
  }

  Future<void> stopApp() async {
    phoneStateController.stopListening();
    stopBackgroundService();
  }

  Future<void> cleanupOnLogout() async {
    // 백그라운드 서비스 정지
    await stopBackgroundService();

    // 전화 상태 감지 중지
    phoneStateController.stopListening();

    // 로컬 알림 정리
    await LocalNotificationService.cancelAllNotifications();

    // 이벤트 구독 해제
    appEventBus.destroy();
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

    // 예시: 안드로이드 config
    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStartOnBoot: false,
        autoStart: false,
        isForegroundMode: false,
        notificationChannelId: 'jumo_data_sync_channel',
        initialNotificationTitle: 'Data Sync Service',
        initialNotificationContent: 'Initializing...',
      ),
      iosConfiguration: IosConfiguration(
        onForeground: onStart,
        autoStart: false,
      ),
    );
  }

  List<Map<String, dynamic>> getNotifications() {
    return List<Map<String, dynamic>>.from(box.read('notifications') ?? []);
  }

  // 만료된 알림 제거
  Future<void> removeExpiredNotifications() async {
    final notifications = getNotifications();
    final now = DateTime.now().toUtc(); // UTC로 변환

    final validNotifications =
        notifications.where((notification) {
          final validUntilStr = notification['validUntil'] as String?;
          if (validUntilStr == null) return true;
          final validUntil = parseServerTime(validUntilStr);
          return validUntil?.isAfter(now) ?? true;
        }).toList();

    if (validNotifications.length != notifications.length) {
      await box.write('notifications', validNotifications);
      appEventBus.fire(NotificationCountUpdatedEvent());
    }
  }

  Future<void> saveNotification({
    required String id,
    required String title,
    required String message,
    String? validUntil,
  }) async {
    // 이미 표시된 알림인지 확인 (타이틀과 메시지로 체크)
    final displayedNotiIds = box.read<List<dynamic>>('displayedNotiIds') ?? [];
    final isDisplayed = displayedNotiIds.any(
      (noti) => noti['title'] == title && noti['message'] == message,
    );

    // 이미 저장된 알림인지 확인
    final notifications = getNotifications();
    final isDuplicate = notifications.any(
      (noti) => noti['title'] == title && noti['message'] == message,
    );

    if (!isDuplicate) {
      notifications.insert(0, {
        'id': id,
        'title': title,
        'message': message,
        'timestamp': DateTime.now().toIso8601String(),
        'validUntil': validUntil,
      });

      await box.write('notifications', notifications);

      // 알림 저장 후 이벤트 발생
      appEventBus.fire(NotificationCountUpdatedEvent());
    }

    // 표시되지 않은 알림만 로컬 알림으로 표시
    if (!isDisplayed) {
      await LocalNotificationService.showNotification(
        id: notifications.length,
        title: title,
        body: message,
      );
      displayedNotiIds.add({'title': title, 'message': message});
      await box.write('displayedNotiIds', displayedNotiIds);
    }
  }

  Future<void> startBackgroundService() async {
    final service = FlutterBackgroundService();
    // already running check
    if (await service.isRunning()) {
      log('[DataSync] Service already running!');
      return;
    }
    // start
    await service.startService();
    log('[DataSync] Service started.');
  }

  Future<void> stopBackgroundService() async {
    final service = FlutterBackgroundService();
    if (!(await service.isRunning())) {
      log('[DataSync] Service not running!');
      return;
    }
    // invoke stopService event
    service.invoke('stopService');
    log('[DataSync] Service stop command sent.');
  }
}
