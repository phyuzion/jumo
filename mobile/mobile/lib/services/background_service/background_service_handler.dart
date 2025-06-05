import 'dart:async';
import 'dart:developer';
import 'dart:ui';
import 'dart:isolate';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:mobile/services/background_service/call_state_manager.dart';
import 'package:mobile/services/background_service/notification_manager.dart';
import 'package:mobile/services/background_service/blocked_list_manager.dart';
import 'package:mobile/services/background_service/service_constants.dart';

@pragma('vm:entry-point')
Future<void> onStart(ServiceInstance service) async {
  // 백그라운드 서비스 실행 시 짧은 딜레이 추가
  await Future.delayed(const Duration(milliseconds: 100));

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // 초기 알림 설정
  try {
    await Future.delayed(const Duration(milliseconds: 200));
    if (service is AndroidServiceInstance) {
      if (await service.isForegroundService()) {
        log(
          '[BackgroundService] Setting initial foreground notification (delayed).',
        );
        flutterLocalNotificationsPlugin.show(
          FOREGROUND_SERVICE_NOTIFICATION_ID,
          'KOLPON',
          '',
          const NotificationDetails(
            android: AndroidNotificationDetails(
              FOREGROUND_SERVICE_CHANNEL_ID,
              'KOLPON 서비스 상태',
              icon: 'ic_bg_service_small',
              ongoing: true,
              autoCancel: false,
              importance: Importance.low,
              priority: Priority.low,
              playSound: false,
              enableVibration: false,
              onlyAlertOnce: true,
            ),
          ),
          payload: 'idle',
        );
        log('[BackgroundService] Initial foreground notification set.');
      }
    }
  } catch (e) {
    log('[BackgroundService][onStart] Error setting initial notification: $e');
  }

  // 검색 데이터 리셋 요청 처리 리스너 추가
  service.on('resetSearchData').listen((event) {
    log('[BackgroundService][CRITICAL] 검색 데이터 리셋 요청 수신');

    // 메인 앱에 리셋 요청 전달
    service.invoke('requestSearchDataReset', {});
  });

  // 통화 상태 관리자 초기화
  final callStateManager = CallStateManager(
    service,
    flutterLocalNotificationsPlugin,
  );
  await callStateManager.initialize();

  // 알림 관리자 초기화
  final notificationManager = NotificationManager(service);
  notificationManager.initialize();

  // 차단 목록 관리자 초기화
  final blockedListManager = BlockedListManager();

  // 초기 백그라운드 작업 수행
  await performInitialBackgroundTasks(service, callStateManager);
  log(
    '[BackgroundService][onStart] Initial background tasks completed. Service is ready.',
  );
}

Future<void> performInitialBackgroundTasks(
  ServiceInstance service,
  CallStateManager callStateManager,
) async {
  log(
    '[BackgroundService][performInitialBackgroundTasks] Starting initial tasks...',
  );

  // 백그라운드 서비스 시작 시 현재 통화 상태 확인 및 캐싱
  await callStateManager.checkInitialCallState();

  // 추가적인 초기화 작업

  log(
    '[BackgroundService][performInitialBackgroundTasks] Initial tasks finished.',
  );
}
