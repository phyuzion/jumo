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
  log('[BackgroundService][onStart] STARTING SERVICE...');

  // Foreground 서비스로 즉시 설정 (Android 12+ 요구사항)
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  if (service is AndroidServiceInstance) {
    try {
      // 즉시 foreground 서비스로 설정 (딜레이 없이)
      await service.setForegroundNotificationInfo(title: 'KOLPON', content: '');
      log('[BackgroundService] Service set as foreground immediately');

      // 알림 채널이 생성되었는지 확인하고 알림 표시
      await Future.delayed(const Duration(milliseconds: 100));

      // 더 완전한 알림 설정
      await flutterLocalNotificationsPlugin.show(
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
      log('[BackgroundService] Enhanced foreground notification displayed');
    } catch (e) {
      log('[BackgroundService] Error setting foreground mode: $e');
    }
  }

  // 검색 데이터 리셋 요청 처리 리스너 추가
  service.on('resetSearchData').listen((event) async {
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
  final blockedListManager = BlockedListManager(service);
  blockedListManager.initialize();

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
