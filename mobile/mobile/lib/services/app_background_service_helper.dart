import 'dart:async';
import 'dart:developer';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';

class BackgroundServiceHelper {
  static final FlutterBackgroundService _service = FlutterBackgroundService();
  static bool _isInitializing = false;
  static DateTime? _lastServiceStartAttempt;

  /// 백그라운드 서비스 상태 확인 및 필요시 자동 재시작
  static Future<bool> ensureServiceRunning({
    bool forceRestart = false,
    Duration throttleInterval = const Duration(minutes: 1),
  }) async {
    // 초기화 중이면 진행 중인 초기화가 완료될 때까지 대기
    if (_isInitializing) {
      log(
        '[BackgroundServiceHelper] Service initialization already in progress. Waiting...',
      );
      int attempts = 0;
      while (_isInitializing && attempts < 10) {
        await Future.delayed(const Duration(seconds: 1));
        attempts++;
      }

      if (_isInitializing) {
        log(
          '[BackgroundServiceHelper] Timeout waiting for initialization to complete.',
        );
        return false;
      }

      // 초기화가 완료되었으면 서비스 상태 확인
      final isRunning = await _service.isRunning();
      log(
        '[BackgroundServiceHelper] Service initialization completed. isRunning=$isRunning',
      );
      return isRunning;
    }

    try {
      // 강제 재시작 요청 또는 서비스가 실행 중이 아닌 경우에만 처리
      final isRunning = await _service.isRunning();

      if (forceRestart || !isRunning) {
        // 너무 빈번한 시작 시도 방지 (스로틀링)
        final now = DateTime.now();
        if (_lastServiceStartAttempt != null &&
            now.difference(_lastServiceStartAttempt!) < throttleInterval &&
            !forceRestart) {
          log(
            '[BackgroundServiceHelper] Service start throttled. Last attempt was at $_lastServiceStartAttempt',
          );
          return isRunning;
        }

        _lastServiceStartAttempt = now;

        if (isRunning && forceRestart) {
          log(
            '[BackgroundServiceHelper] Stopping service for forced restart...',
          );
          _service.invoke('stopService');
          await Future.delayed(const Duration(seconds: 1)); // 서비스 종료 대기
        }

        log('[BackgroundServiceHelper] Starting background service...');
        _isInitializing = true;

        // 서비스 설정 및 시작
        await _initializeService();

        // 서비스 시작 후 상태 확인
        await Future.delayed(const Duration(seconds: 2));
        final isNowRunning = await _service.isRunning();
        log(
          '[BackgroundServiceHelper] Service start ${isNowRunning ? "successful" : "failed"}',
        );

        _isInitializing = false;
        return isNowRunning;
      } else {
        log('[BackgroundServiceHelper] Service is already running.');
        return true;
      }
    } catch (e) {
      log('[BackgroundServiceHelper] Error ensuring service is running: $e');
      _isInitializing = false;
      return false;
    }
  }

  /// 백그라운드 서비스 초기화 및 설정
  static Future<void> _initializeService() async {
    try {
      final service = FlutterBackgroundService();

      // Notifications 채널 설정
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'jumo_foreground_service_channel',
        'KOLPON 서비스 상태',
        description: 'KOLPON 앱이 백그라운드에서 실행 중임을 알려줍니다.',
        importance: Importance.low,
      );

      final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
          FlutterLocalNotificationsPlugin();

      if (defaultTargetPlatform == TargetPlatform.android) {
        await flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.createNotificationChannel(channel);
      }

      // 서비스 설정
      await service.configure(
        androidConfiguration: AndroidConfiguration(
          onStart: onStart,
          autoStart: true,
          isForegroundMode: true,
          notificationChannelId: 'jumo_foreground_service_channel',
          initialNotificationTitle: 'KOLPON',
          initialNotificationContent: '백그라운드 서비스 실행 중',
          foregroundServiceNotificationId: 777,
        ),
        iosConfiguration: IosConfiguration(
          autoStart: true,
          onForeground: onStart,
          onBackground: onIosBackground,
        ),
      );

      log('[BackgroundServiceHelper] Service configuration completed.');
    } catch (e) {
      log('[BackgroundServiceHelper] Error initializing service: $e');
      rethrow;
    }
  }
}

// Required for iOS
@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  return true;
}

// Required as a reference to the actual onStart function
@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  // 여기는 간단한 참조만 두고, 실제 구현은 app_background_service.dart에 둡니다.
  // 이렇게 하면 모듈성이 유지되고 코드 중복을 방지할 수 있습니다.
  log(
    '[BackgroundServiceHelper] onStart called, delegating to real implementation...',
  );
}
