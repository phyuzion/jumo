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

    // <<< 필요한 모든 채널 생성 >>>
    await _createNotificationChannels();
    // <<< 기존 채널 생성 로직 제거 >>>
    // const AndroidNotificationChannel foregroundChannel = ... ;
    // const AndroidNotificationChannel ongoingCallChannel = ... ;
    // await _plugin...createNotificationChannel(foregroundChannel);
    // await _plugin...createNotificationChannel(ongoingCallChannel);
    // log(...);
  }

  // <<< 알림 채널 생성 헬퍼 함수 추가 >>>
  static Future<void> _createNotificationChannels() async {
    final flutterLocalNotificationsPlugin =
        _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
    if (flutterLocalNotificationsPlugin == null) {
      log(
        '[LocalNotification] Android implementation not found, cannot create channels.',
      );
      return;
    }

    // 1. 일반 알림 채널 (showNotification용)
    const AndroidNotificationChannel generalChannel =
        AndroidNotificationChannel(
          'jumo_channel_id',
          '일반 알림', // 채널 이름 (사용자 설정)
          description: '앱 관련 일반 알림',
          importance: Importance.max, // <<< 일반 알림 중요도 설정
        );
    await flutterLocalNotificationsPlugin.createNotificationChannel(
      generalChannel,
    );

    // 2. 부재중 전화 채널 (showMissedCallNotification용)
    const AndroidNotificationChannel missedCallChannel =
        AndroidNotificationChannel(
          'missed_call_channel_id',
          '부재중 전화',
          description: '부재중 전화 알림',
          importance: Importance.high, // 부재중은 중요
        );
    await flutterLocalNotificationsPlugin.createNotificationChannel(
      missedCallChannel,
    );

    // 3. 포그라운드 서비스 채널
    const AndroidNotificationChannel foregroundChannel =
        AndroidNotificationChannel(
          'jumo_foreground_service_channel',
          'KOLPON 서비스 상태',
          description: '앱 보호 및 동기화 서비스 상태 알림',
          importance: Importance.low, // 방해 최소화
          playSound: false,
          enableVibration: false,
        );
    await flutterLocalNotificationsPlugin.createNotificationChannel(
      foregroundChannel,
    );

    // 4. (선택/제거) 진행 중 통화 채널 - 현재 사용 안 함
    // const AndroidNotificationChannel ongoingCallChannel = ...;
    // await flutterLocalNotificationsPlugin.createNotificationChannel(ongoingCallChannel);

    log('[LocalNotification] All required notification channels created.');
  }

  // 일반 알림 표시 (채널 ID 확인)
  static Future<void> showNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'jumo_channel_id', // <<< 채널 ID 확인
      '일반 알림', // <<< 채널 이름 확인
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      icon: 'app_icon',
    );
    const details = NotificationDetails(android: androidDetails);
    await _plugin.show(id, title, body, details);
  }

  // (C) 통화 중 알림 (ongoing)
  // static Future<void> showOngoingCallNotification({ ... }) async { ... }

  // (D) 부재중 전화 알림 (채널 ID 확인)
  static Future<void> showMissedCallNotification({
    required int id,
    required String callerName,
    required String phoneNumber,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'missed_call_channel_id', // <<< 채널 ID 확인
      '부재중 전화', // <<< 채널 이름 확인
      channelDescription: '부재중 전화 알림',
      importance: Importance.high,
      priority: Priority.high,
      icon: 'missed_icon', // 필요 시 아이콘 지정
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

  // <<< 페이로드 처리 및 네비게이션 함수 (수정) >>>
  static void handlePayloadNavigation(String payload) {
    final parts = payload.split(':');
    if (parts.length < 1) return;

    final type = parts[0];
    final number = parts.length > 1 ? parts[1] : '';

    log('[LocalNotification] Handling payload: type=$type, number=$number');

    // <<< 네비게이션 로직 제거 >>>
    // Provider 업데이트는 앱 실행 시 main.dart에서 처리하거나,
    // 앱 실행 중에는 _listenToBackgroundService에서 처리되므로 여기서 직접 호출 불필요.

    // final currentContext = NavigationController.navKey.currentContext;
    // if (currentContext == null) {
    //   log('[LocalNotification] Cannot navigate: Navigator context is null.');
    //   return;
    // }
    // log('[LocalNotification] Navigating based on payload: type=$type, number=$number');
    // switch (type) {
    //   case 'incoming':
    //     NavigationController.goToIncoming(number);
    //     break;
    //   // ... (다른 case)
    // }
  }
}
