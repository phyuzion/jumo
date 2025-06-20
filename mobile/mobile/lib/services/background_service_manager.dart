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

    try {
      // 1. 알림 채널 생성 확인 - 가장 먼저 수행
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        FOREGROUND_SERVICE_CHANNEL_ID,
        'KOLPON 서비스 상태',
        importance: Importance.low,
        showBadge: false,
      );

      const AndroidNotificationChannel missedCallChannel =
          AndroidNotificationChannel(
            'missed_call_channel_id',
            '부재중 전화',
            importance: Importance.high,
            showBadge: false,
          );

      const AndroidNotificationChannel notificationChannel =
          AndroidNotificationChannel(
            'jumo_notification_channel',
            'KOLPON 알림',
            importance: Importance.high,
            showBadge: false,
          );

      // 수신 전화 알림 채널 추가
      const AndroidNotificationChannel incomingCallChannel =
          AndroidNotificationChannel(
            'incoming_call_channel_id',
            '수신 전화',
            description: '수신 전화 알림',
            importance: Importance.max,
            showBadge: false,
          );

      final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
          FlutterLocalNotificationsPlugin();

      final AndroidFlutterLocalNotificationsPlugin? androidNotifications =
          flutterLocalNotificationsPlugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >();

      if (androidNotifications != null) {
        // 각 채널 생성 확인
        await androidNotifications.createNotificationChannel(channel);
        await androidNotifications.createNotificationChannel(missedCallChannel);
        await androidNotifications.createNotificationChannel(
          notificationChannel,
        );
        // 수신 전화 채널 추가
        await androidNotifications.createNotificationChannel(
          incomingCallChannel,
        );

        log('[AppBackgroundService] All notification channels created');
      } else {
        log(
          '[AppBackgroundService] Failed to get Android notifications implementation',
        );
      }

      // 2. 알림 초기화
      await flutterLocalNotificationsPlugin.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('app_icon'),
          iOS: DarwinInitializationSettings(),
        ),
        onDidReceiveNotificationResponse: (details) {
          log(
            '[AppBackgroundService] Notification response received: ${details.payload}',
          );
        },
      );

      // 3. 서비스 구성 - 원본 설정으로 복원
      final service = FlutterBackgroundService();
      await service.configure(
        androidConfiguration: AndroidConfiguration(
          onStart: onStart,
          autoStartOnBoot: false,
          autoStart: false, // 원본대로 false로 변경
          isForegroundMode: true, // 중요: foreground 모드 활성화
          notificationChannelId: FOREGROUND_SERVICE_CHANNEL_ID,
          initialNotificationTitle: 'KOLPON',
          initialNotificationContent: '',
          foregroundServiceNotificationId: FOREGROUND_SERVICE_NOTIFICATION_ID,
        ),
        iosConfiguration: IosConfiguration(
          autoStart: false, // 원본대로 false로 변경
          onForeground: onStart,
          onBackground: onIosBackground,
        ),
      );

      log('[AppBackgroundService] Background service configuration completed');
    } catch (e) {
      log('[AppBackgroundService] Error initializing background service: $e');
    }
  }
}

// iOS 백그라운드 핸들러
@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  log('[AppBackgroundService] iOS background handler invoked.');
  return true;
}
