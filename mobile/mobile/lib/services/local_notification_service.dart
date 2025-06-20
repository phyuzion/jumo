// lib/services/local_notification_service.dart
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:async';
import 'dart:developer';
import 'dart:typed_data'; // Int64List 를 위한 import 추가
import 'dart:ui'; // Color 를 위한 import 추가

// NavigatorKey 등 활용하려면 import
import 'package:mobile/controllers/navigation_controller.dart';

// 통화 상태 알림 전용 ID
const int CALL_STATUS_NOTIFICATION_ID = 9876;
const String INCOMING_CALL_CHANNEL_ID = 'incoming_call_channel_id';

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

        // 페이로드가 있으면 처리
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
          showBadge: false, // <<< 추가: 이 채널의 알림은 앱 아이콘 배지에 표시되지 않도록 설정
        );
    await flutterLocalNotificationsPlugin.createNotificationChannel(
      foregroundChannel,
    );

    // 4. 수신 전화 채널 추가
    // 진동 및 LED 설정은 const가 아닐 수 있으므로 non-const로 생성
    final AndroidNotificationChannel incomingCallChannel =
        AndroidNotificationChannel(
          INCOMING_CALL_CHANNEL_ID,
          '수신 전화',
          description: '수신 전화 알림',
          importance: Importance.max,
          // vibrationPattern과 ledColor는 여기서 제외하고 노티피케이션에서 설정
        );
    await flutterLocalNotificationsPlugin.createNotificationChannel(
      incomingCallChannel,
    );

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

  // 수신 전화 알림 표시
  static Future<void> showIncomingCallNotification({
    required String phoneNumber,
    String callerName = '',
  }) async {
    // 이미 동일한 번호로 알림이 있으면 취소 후 새로 표시
    await cancelNotification(CALL_STATUS_NOTIFICATION_ID);

    try {
      final displayName = callerName.isNotEmpty ? callerName : phoneNumber;

      // 부재중 전화처럼 간단하게 설정
      final androidDetails = AndroidNotificationDetails(
        INCOMING_CALL_CHANNEL_ID,
        '수신 전화',
        channelDescription: '수신 전화 알림',
        importance: Importance.high,
        priority: Priority.high,
        fullScreenIntent: true,
        ongoing: true,
        playSound: true,
        icon: 'app_icon',
      );

      final details = NotificationDetails(android: androidDetails);

      // 이름이 있으면 이름을 타이틀에, 없으면 "전화 수신중"을 타이틀에
      final title = callerName.isNotEmpty ? callerName : '📞 전화 수신중';

      // 내용에는 전화번호만 표시
      final body = phoneNumber;

      final payload = 'incoming:$phoneNumber';

      await _plugin.show(
        CALL_STATUS_NOTIFICATION_ID,
        title,
        body,
        details,
        payload: payload,
      );

      log(
        '[LocalNotification] Showed incoming call notification for: $displayName ($phoneNumber)',
      );
    } catch (e) {
      log('[LocalNotification] Error showing incoming call notification: $e');
    }
  }

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

    // 네비게이션 로직 - 페이로드 타입에 따라 처리
    final currentContext = NavigationController.navKey.currentContext;
    if (currentContext == null) {
      log('[LocalNotification] Cannot navigate: Navigator context is null.');
      return;
    }

    if (type == 'incoming') {
      log('[LocalNotification] Navigating to incoming call screen: $number');
      NavigationController.goToDecider();
    } else if (type == 'missed') {
      log(
        '[LocalNotification] Navigating to call logs for missed call: $number',
      );
      NavigationController.goToDecider();
    }
  }
}
