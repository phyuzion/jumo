// lib/services/local_notification_service.dart
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:async';

// NavigatorKey 등 활용하려면 import
// import 'package:mobile/controllers/navigation_controller.dart';

class LocalNotificationService {
  static final _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // 초기화
  static Future<void> initialize() async {
    const androidInit = AndroidInitializationSettings('app_icon');
    const initSettings = InitializationSettings(android: androidInit);

    // 알림 탭 콜백
    await _flutterLocalNotificationsPlugin.initialize(initSettings);
  }

  // (A) 일반 알림 (이미 있던)
  static Future<void> showNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'jumo_channel_id',
      'jumo_channel_name',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      icon: 'app_icon',
    );
    const details = NotificationDetails(android: androidDetails);
    await _flutterLocalNotificationsPlugin.show(id, title, body, details);
  }

  // (B) 수신 전화 알림
  static Future<void> showIncomingCallNotification({
    required int id,
    required String callerName,
    required String phoneNumber,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'incoming_call_channel_id',
      'Incoming Call',
      channelDescription: '전화가 오고 있습니다.',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      icon: 'app_icon',
    );
    final details = NotificationDetails(android: androidDetails);

    final title = '전화가 오고 있습니다.';
    final body =
        callerName.isNotEmpty ? '$callerName | $phoneNumber' : phoneNumber;

    await _flutterLocalNotificationsPlugin.show(
      id,
      title,
      body,
      details,
      payload: 'incoming_call:$phoneNumber',
    );
  }

  // (C) 통화 중 알림 (ongoing)
  static Future<void> showOngoingCallNotification({
    required int id,
    required String callerName,
    required String phoneNumber,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      'ongoing_call_channel_id',
      'Ongoing Call',
      channelDescription: '현재 통화중임을 알림',
      importance: Importance.max,
      priority: Priority.high,
      ongoing: true, // 지울 수 없음
      autoCancel: false, // 탭해도 자동으로 사라지지 않음
      playSound: false,
      enableVibration: false,
      icon: 'app_icon',
    );

    final details = NotificationDetails(android: androidDetails);
    final title = '통화 중';
    final body =
        callerName.isNotEmpty ? '$callerName | $phoneNumber' : phoneNumber;

    await _flutterLocalNotificationsPlugin.show(
      id,
      title,
      body,
      details,
      payload: 'ongoing_call:$phoneNumber',
    );
  }

  // (D) 부재중 전화 알림
  static Future<void> showMissedCallNotification({
    required int id,
    required String callerName,
    required String phoneNumber,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'missed_call_channel_id',
      'Missed Call',
      channelDescription: '부재중 전화 알림',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      icon: 'missed_icon',
    );
    final details = NotificationDetails(android: androidDetails);

    final title = '부재중 전화가 있습니다.';
    final body =
        callerName.isNotEmpty ? '$callerName | $phoneNumber' : phoneNumber;

    await _flutterLocalNotificationsPlugin.show(
      id,
      title,
      body,
      details,
      payload: 'missed_call:$phoneNumber',
    );
  }

  // 알림 취소
  static Future<void> cancelNotification(int id) async {
    await _flutterLocalNotificationsPlugin.cancel(id);
  }
}
