// lib/services/app_background_service.dart

import 'dart:async';
import 'dart:developer';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:mobile/controllers/sms_controller.dart';
import 'package:mobile/graphql/notification_api.dart';
import 'package:mobile/services/local_notification_service.dart';

/// 전역 or static 으로 저장할 수도 있음
int lastNotificationId = 0;

@pragma('vm:entry-point')
Future<void> onStart(ServiceInstance service) async {
  if (service is AndroidServiceInstance) {
    service.setAsForegroundService();
    service.setForegroundNotificationInfo(
      title: "Data Sync Service",
      content: "Synchronizing call log, sms, notifications every minute...",
    );
  }

  final smsController = SmsController();

  // 1) 1분 주기로 반복
  Timer.periodic(const Duration(seconds: 10), (timer) async {
    // 1-A) SMS 갱신
    await smsController.refreshSms();

    // 1-B) 서버 알림 가져오기
    final notiList = await NotificationApi.getNotifications();
    // 예: 알림이 [ {id, title, message, validUntil, ...}, ... ]

    if (notiList.isEmpty) return;

    // 2) validUntil 체크(서버에서 이미 필터링되었다면 필요없음)
    final now = DateTime.now();
    final filtered =
        notiList.where((n) {
          final validStr = n['validUntil'] as String?;
          if (validStr == null) return true; // 유효기간 없으면 표시
          final validTime = DateTime.tryParse(validStr);
          if (validTime == null) return true;
          return now.isBefore(validTime);
        }).toList();

    if (filtered.isEmpty) return;

    // 3) 알림 ID 정렬(오름차순) => 가장 옛것부터 새것 순으로 표시
    filtered.sort((a, b) {
      final aId = int.tryParse((a['id'] ?? '0').toString()) ?? 0;
      final bId = int.tryParse((b['id'] ?? '0').toString()) ?? 0;
      return aId.compareTo(bId);
    });

    // 4) "newId > lastNotificationId"만 표시
    for (final n in filtered) {
      final sid = n['id']?.toString() ?? '0';
      final newId = int.tryParse(sid) ?? 0;

      if (newId <= lastNotificationId) {
        // 이미 표시한 알림이거나 더 오래된 것 => skip
        continue;
      }

      final title = n['title'] as String? ?? 'No Title';
      final message = n['message'] as String? ?? '...';

      log('noti : $title , body : $message');
      // 5) 로컬 노티
      //    ID는 newId (혹은 Random())
      //    소리/진동 등은 LocalNotificationService.showNotification 에서 설정
      await LocalNotificationService.showNotification(
        id: newId,
        title: title,
        body: message,
      );

      // 6) lastNotificationId 갱신
      if (newId > lastNotificationId) {
        lastNotificationId = newId;
      }
    }
  });

  // stopService event => self stop
  service.on('stopService').listen((event) {
    service.stopSelf();
  });
}
