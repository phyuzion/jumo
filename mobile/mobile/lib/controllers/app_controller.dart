// lib/controllers/app_controller.dart
import 'dart:developer';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:mobile/controllers/call_log_controller.dart';
import 'package:mobile/controllers/contacts_controller.dart';
import 'package:mobile/controllers/permission_controller.dart';
import 'package:mobile/controllers/phone_state_controller.dart';
import 'package:mobile/controllers/sms_controller.dart';
import 'package:mobile/services/app_background_service.dart';
import 'package:mobile/services/native_methods.dart';
import 'package:get_storage/get_storage.dart';
import 'package:mobile/controllers/navigation_controller.dart';

class AppController {
  late final PhoneStateController phoneStateController;

  Future<bool> checkEssentialPermissions() async {
    return await PermissionController.requestAllEssentialPermissions();
  }

  Future<void> initializeApp() async {
    await GetStorage.init();
    final myNumber = await NativeMethods.getMyPhoneNumber();
    log('myNumber=$myNumber');
    GetStorage().write('myNumber', myNumber);

    phoneStateController = PhoneStateController(NavigationController.navKey);
    phoneStateController.startListening();

    await initializeData();

    configureBackgroundService();
    startBackgroundService();
  }

  Future<void> initializeData() async {
    // 컨트롤러들(실제 diff 로직)
    final callLogController = CallLogController();
    final smsController = SmsController();
    final contactsController = ContactsController();

    // 10분 타이머
    final newCalls = await callLogController.refreshCallLogsWithDiff();
    if (newCalls.isNotEmpty) {
      // TODO: 필요 시 서버에 전송, 로컬DB 저장, 등
      log('[DataSync] new calls => ${newCalls.length}');
      log('[DataSync] new calls => ${newCalls}');
    }

    // === 2) sms diff ===
    final newSms = await smsController.refreshSmsWithDiff();
    if (newSms.isNotEmpty) {
      log('[DataSync] new sms => ${newSms.length}');
      log('[DataSync] new sms => ${newSms}');
      // ...
    }

    // === 3) contacts diff ===
    final newContacts = await contactsController.refreshContactsWithDiff();
    if (newContacts.isNotEmpty) {
      log('[DataSync] new or changed contacts => ${newContacts.length}');
      log('[DataSync] new or changed contacts => ${newContacts}');
      // ...
    }
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
