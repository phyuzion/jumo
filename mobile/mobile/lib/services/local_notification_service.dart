// lib/services/local_notification_service.dart
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:async';
import 'dart:developer';
import 'package:flutter/material.dart'; // NavigatorState 사용 위해 추가
import 'package:mobile/controllers/navigation_controller.dart'; // NavigationController 사용 위해 추가

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
    await _plugin.initialize(
      initSettings,
      // <<< 알림 탭 콜백 (앱 실행 중) >>>
      onDidReceiveNotificationResponse: (
        NotificationResponse notificationResponse,
      ) async {
        log(
          '[LocalNotification] Notification tapped (foreground): Payload=${notificationResponse.payload}',
        );
        if (notificationResponse.payload != null) {
          handlePayloadNavigation(notificationResponse.payload!);
        }
      },
      // <<< 백그라운드 알림 탭 콜백 (선택 사항) >>>
      // onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

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
      'missed_call_channel_id', // 부재중 전용 채널 (생성 필요)
      'Missed Call',
      channelDescription: '부재중 전화 알림',
      importance: Importance.high,
      priority: Priority.high,
      // icon: 'missed_icon', // 필요 시 아이콘 지정
    );
    final details = NotificationDetails(android: androidDetails);
    final title = '부재중 전화';
    final body =
        callerName.isNotEmpty ? '$callerName ($phoneNumber)' : phoneNumber;
    final payload = 'missed:$phoneNumber'; // <<< payload 추가

    await _plugin.show(
      id,
      title,
      body,
      details,
      payload: payload, // <<< payload 전달
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

  // 페이로드 처리 및 네비게이션 함수 (public으로 변경)
  static void handlePayloadNavigation(String payload) {
    final parts = payload.split(':');
    if (parts.length < 1) return;

    final type = parts[0];
    final number = parts.length > 1 ? parts[1] : '';

    final currentContext = NavigationController.navKey.currentContext;
    if (currentContext == null) {
      log('[LocalNotification] Cannot navigate: Navigator context is null.');
      return;
    }

    log(
      '[LocalNotification] Navigating based on payload: type=$type, number=$number',
    );

    // 이미 해당 화면에 있는지 확인하는 로직 추가하면 더 좋음

    switch (type) {
      case 'incoming':
        NavigationController.goToIncoming(number);
        break;
      case 'active':
        NavigationController.goToOnCall(number, true);
        break;
      case 'missed':
        NavigationController.goToCallEnded(number, 'missed');
        break;
      case 'idle':
        // 기본 상태 알림 탭 시 동작 정의 (예: 홈으로 가거나 아무것도 안 함)
        // Navigator.pushNamedAndRemoveUntil(currentContext, '/home', (route) => false);
        break;
      default:
        log('[LocalNotification] Unknown payload type: $type');
    }
  }
}
