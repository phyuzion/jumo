// lib/services/app_background_service.dart

import 'dart:async';
import 'dart:developer';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:get_storage/get_storage.dart';
import 'package:mobile/controllers/sms_controller.dart';
import 'package:mobile/graphql/notification_api.dart';
import 'package:mobile/services/local_notification_service.dart';

@pragma('vm:entry-point')
Future<void> onStart(ServiceInstance service) async {
  if (service is AndroidServiceInstance) {
    service.setAsForegroundService();
    service.setForegroundNotificationInfo(
      title: "Data Sync Service",
      content: "Synchronizing call log, sms, notifications every minute...",
    );
  }

  final box = GetStorage();

  final displayedStrList = box.read<List<dynamic>>('displayedNotiIds') ?? [];
  final displayedNotiIds = displayedStrList.map((e) => e.toString()).toSet();

  final smsController = SmsController();

  // 1분마다
  Timer.periodic(const Duration(minutes: 1), (timer) async {
    // SMS
    await smsController.refreshSms();

    // 서버 알림
    final notiList = await NotificationApi.getNotifications();
    if (notiList.isEmpty) return;

    // 예: 알림 id가 String 형태라고 가정
    // 중복 방지: displayedNotiIds 에 이미 있다면 skip
    for (final n in notiList) {
      final sid = (n['id'] ?? '').toString();
      if (sid.isEmpty) continue;

      if (displayedNotiIds.contains(sid)) {
        continue;
      }

      // 새 알림 -> 표시
      final title = n['title'] as String? ?? 'No Title';
      final message = n['message'] as String? ?? '...';
      log('[BackgroundService] show local noti => $title / $message');

      // flutter_local_notifications
      // id: int가 필요하니 sid를 int 변환 or random
      final idInt = int.tryParse(sid) ?? DateTime.now().millisecondsSinceEpoch;
      await LocalNotificationService.showNotification(
        id: idInt,
        title: title,
        body: message,
      );

      // displayedNotiIds 에 추가
      displayedNotiIds.add(sid);
    }

    box.write('displayedNotiIds', displayedNotiIds.toList());
  });

  // stopService => self stop
  service.on('stopService').listen((event) {
    service.stopSelf();
  });
}
