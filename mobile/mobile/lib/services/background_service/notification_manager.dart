import 'dart:developer';
import 'dart:async';
import 'package:flutter_background_service/flutter_background_service.dart';

class NotificationManager {
  final ServiceInstance _service;
  Timer? _notificationTimer;
  static const Duration _notificationInterval = Duration(minutes: 10);

  NotificationManager(this._service);

  void initialize() {
    _setupEventListeners();
    _setupPeriodicNotificationFetch();
  }

  void _setupPeriodicNotificationFetch() {
    // 초기 알림 요청 (즉시 실행)
    _fetchNotifications();

    // 10분마다 알림 요청
    _notificationTimer = Timer.periodic(_notificationInterval, (_) {
      _fetchNotifications();
    });
  }

  void _fetchNotifications() {
    log('[NotificationManager] Requesting notifications from main isolate...');
    _service.invoke('requestNotifications');
  }

  void _setupEventListeners() {
    // 노티피케이션 응답 리스너 추가
    _service.on('notificationsResponse').listen((event) {
      try {
        final notiList = event?['notifications'] as List<dynamic>?;

        if (notiList == null || notiList.isEmpty) return;

        // 만료된 알림 제거 요청
        _service.invoke('removeExpiredNotifications');

        // 서버에 있는 알림 ID 목록을 추출
        final serverNotificationIds = <String>[];

        // 각 알림 처리
        for (final n in notiList) {
          final sid = (n['id'] ?? '').toString();
          if (sid.isEmpty) continue;

          // 서버 ID 목록에 추가
          serverNotificationIds.add(sid);

          _service.invoke('saveNotification', {
            'id': sid,
            'title': n['title'] as String? ?? 'No Title',
            'message': n['message'] as String? ?? '...',
            'validUntil': n['validUntil'],
          });
        }

        // 서버에 없는 노티피케이션을 로컬에서 삭제 요청
        if (serverNotificationIds.isNotEmpty) {
          log(
            '[NotificationManager] Requesting to sync local notifications with server IDs: ${serverNotificationIds.length} IDs',
          );
          _service.invoke('syncNotificationsWithServer', {
            'serverIds': serverNotificationIds,
          });
        }
      } catch (e) {
        log(
          '[NotificationManager] Error processing notifications response: $e',
        );
      }
    });

    // 노티피케이션 에러 리스너 추가
    _service.on('notificationsError').listen((event) {
      final errorMsg = event?['error'] as String? ?? 'Unknown error';
      log(
        '[NotificationManager] Error from main isolate when fetching notifications: $errorMsg',
      );
    });
  }
}
