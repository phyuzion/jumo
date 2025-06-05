// lib/services/background_service_manager.dart

import 'dart:async';
import 'dart:developer';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:mobile/services/background_service/service_constants.dart';
// onStart 함수 참조
import 'package:mobile/services/background_service/background_service_handler.dart'
    show onStart;

class AppBackgroundService {
  static Future<void> initializeService() async {
    log('[AppBackgroundService] Initializing background service...');

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      FOREGROUND_SERVICE_CHANNEL_ID,
      'KOLPON 서비스 상태',
      importance: Importance.low,
      showBadge: false,
    );

    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);

    await flutterLocalNotificationsPlugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('ic_bg_service_small'),
        iOS: DarwinInitializationSettings(),
      ),
    );

    await FlutterBackgroundService().configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: true,
        isForegroundMode: true,
        notificationChannelId: FOREGROUND_SERVICE_CHANNEL_ID,
        initialNotificationTitle: 'KOLPON',
        initialNotificationContent: '',
        foregroundServiceNotificationId: FOREGROUND_SERVICE_NOTIFICATION_ID,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: true,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );

    log('[AppBackgroundService] Background service initialized.');
  }
}

// iOS 백그라운드 핸들러
@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  log('[AppBackgroundService] iOS background handler invoked.');
  return true;
}
