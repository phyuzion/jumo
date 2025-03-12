// lib/services/local_notification_service.dart

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:async';

class LocalNotificationService {
  static final _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // 초기화
  static Future<void> initialize() async {
    const androidInit = AndroidInitializationSettings('app_icon');
    // iOS 설정 필요 시...
    const initSettings = InitializationSettings(android: androidInit);
    await _flutterLocalNotificationsPlugin.initialize(initSettings);
  }

  static Future<void> showNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'jumo_channel_id', // 임의
      'jumo_channel_name', // 임의

      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
    );
    const details = NotificationDetails(android: androidDetails);
    await _flutterLocalNotificationsPlugin.show(id, title, body, details);
  }
}
