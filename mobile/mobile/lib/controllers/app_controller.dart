// lib/controllers/app_controller.dart
import 'dart:developer';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:mobile/controllers/call_log_controller.dart';
import 'package:mobile/controllers/contacts_controller.dart';
import 'package:mobile/controllers/permission_controller.dart';
import 'package:mobile/controllers/phone_state_controller.dart';
import 'package:mobile/controllers/sms_controller.dart';
import 'package:mobile/services/app_background_service.dart';
import 'package:mobile/services/local_notification_service.dart';

class AppController {
  final PhoneStateController phoneStateController;
  final ContactsController contactsController;
  final CallLogController callLogController;
  final SmsController smsController;

  AppController(
    this.phoneStateController,
    this.contactsController,
    this.callLogController,
    this.smsController,
  );

  Future<bool> checkEssentialPermissions() async {
    return await PermissionController.requestAllEssentialPermissions();
  }

  Future<void> initializeApp() async {
    await initializeData();
    await LocalNotificationService.initialize();

    phoneStateController.startListening();
  }

  Future<void> initializeData() async {
    // 컨트롤러들(실제 diff 로직)

    await contactsController.syncContactsAll();
    await callLogController.refreshCallLogs();
    await smsController.refreshSms();
  }

  Future<void> stopApp() async {
    phoneStateController.stopListening();
    stopBackgroundService();
  }

  /// flutter_background_service config
  Future<void> configureBackgroundService() async {
    final service = FlutterBackgroundService();

    // 예시: 안드로이드 config
    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart, // top-level function from app_background_service.dart
        autoStartOnBoot: false,
        autoStart: false,
        isForegroundMode: false,
        notificationChannelId: 'jumo_data_sync_channel',
        initialNotificationTitle: 'Data Sync Service',
        initialNotificationContent: 'Initializing...',
      ),
      iosConfiguration: IosConfiguration(
        // iOS는 제한적
        onForeground: onStart,
        autoStart: false,
      ),
    );
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
