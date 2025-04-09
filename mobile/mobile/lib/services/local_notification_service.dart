// lib/services/local_notification_service.dart
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:async';
import 'dart:developer';

// NavigatorKey 등 활용하려면 import
// import 'package:mobile/controllers/navigation_controller.dart';

// 통화 상태 알림 전용 ID
// const int CALL_STATUS_NOTIFICATION_ID = 1111;

class LocalNotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  // 초기화
  static Future<void> initialize() async {
    const androidInit = AndroidInitializationSettings('app_icon');
    const initSettings = InitializationSettings(android: androidInit);

    // 알림 탭 콜백
    await _plugin.initialize(initSettings);

    // >>> 포그라운드 서비스 전용 채널 추가
    const AndroidNotificationChannel foregroundChannel =
        AndroidNotificationChannel(
          'jumo_foreground_service_channel', // 채널 ID (app_controller와 일치)
          'KOLPON 서비스 상태', // 채널 이름 (사용자 설정에 표시됨)
          description: '앱 보호 및 동기화 서비스 상태 알림', // 채널 설명
          importance: Importance.low, // <<< 중요도를 낮게 설정하여 방해 최소화
          playSound: false, // 소리 끔
          enableVibration: false, // 진동 끔
        );
    // <<< 진행 중 통화 채널 추가 (잘못된 파라미터 제거 및 중요도 조정)
    const AndroidNotificationChannel ongoingCallChannel =
        AndroidNotificationChannel(
          'jumo_ongoing_call_channel',
          'Ongoing Call', // 채널 이름
          description: '현재 통화중임을 알림', // 채널 설명
          importance: Importance.low, // <<< 중요도를 낮게 설정 (방해 최소화)
          playSound: false,
          enableVibration: false,
        );

    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(foregroundChannel); // <<< 포그라운드 채널 생성
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(
          ongoingCallChannel,
        ); // <<< 진행 중 통화 채널 생성 (수정됨)
    log(
      '[LocalNotification] Default, Foreground, and Ongoing channels created.',
    );
  }

  // 일반 알림 표시
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
    await _plugin.show(id, title, body, details);
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

    await _plugin.show(
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

    await _plugin.show(
      id,
      title,
      body,
      details,
      payload: 'missed_call:$phoneNumber',
    );
  }

  // 특정 알림 취소
  static Future<void> cancelNotification(int id) async {
    await _plugin.cancel(id);
    log('[LocalNotification] Canceled notification (ID: $id)');
  }

  // 모든 알림 취소
  static Future<void> cancelAllNotifications() async {
    await _plugin.cancelAll();
    log('[LocalNotification] Canceled all notifications.');
  }
}
