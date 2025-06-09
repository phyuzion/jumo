import 'dart:developer';
import 'package:flutter/widgets.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:mobile/graphql/notification_api.dart';
import 'package:mobile/repositories/notification_repository.dart';
import 'package:mobile/utils/app_event_bus.dart';
import 'package:provider/provider.dart';

class NotificationListenerService {
  final BuildContext context;
  final FlutterBackgroundService _service;

  NotificationListenerService(this.context, this._service) {
    _setupListeners();
  }

  void _setupListeners() {
    // 노티피케이션 요청 리스너
    _service.on('requestNotifications').listen(_handleRequestNotifications);

    // 노티피케이션 동기화 리스너
    _service.on('syncNotificationsWithServer').listen(_handleSyncNotifications);
  }

  void _handleRequestNotifications(Map<String, dynamic>? event) async {
    if (!context.mounted) return;
    log(
      '[NotificationListenerService] Received requestNotifications from background service',
    );

    try {
      // 메인 isolate에서 API 호출 실행 (인증된 상태)
      final notiList = await NotificationApi.getNotifications();
      log(
        '[NotificationListenerService] Fetched ${notiList.length} notifications from API',
      );

      // 결과를 백그라운드 서비스로 전송
      _service.invoke('notificationsResponse', {'notifications': notiList});
    } catch (e) {
      log('[NotificationListenerService] Error fetching notifications: $e');
      // 오류 정보를 백그라운드 서비스로 전송
      _service.invoke('notificationsError', {'error': e.toString()});
    }
  }

  void _handleSyncNotifications(Map<String, dynamic>? event) async {
    if (!context.mounted) return;
    final serverIds = event?['serverIds'] as List<dynamic>?;
    log(
      '[NotificationListenerService] Received syncNotificationsWithServer, server IDs: ${serverIds?.length ?? 0}',
    );

    if (serverIds == null || serverIds.isEmpty) {
      log(
        '[NotificationListenerService] No server IDs provided. Skipping sync.',
      );
      return;
    }

    try {
      final notificationRepository = context.read<NotificationRepository>();
      // 문자열 목록으로 변환
      final stringIds = serverIds.map((id) => id.toString()).toList();
      final deletedCount = await notificationRepository.syncWithServerIds(
        stringIds,
      );
      log(
        '[NotificationListenerService] Synced notifications. Deleted $deletedCount notifications.',
      );

      // 노티피케이션 카운트 업데이트 이벤트 발행
      if (deletedCount > 0) {
        log(
          '[NotificationListenerService] Broadcasting notification count update event',
        );
        appEventBus.fire(NotificationCountUpdatedEvent());
      }
    } catch (e) {
      log(
        '[NotificationListenerService] Error syncing notifications with server: $e',
      );
    }
  }
}
