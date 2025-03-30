// lib/services/app_background_service.dart

import 'dart:async';
import 'dart:developer';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:get_storage/get_storage.dart';
import 'package:mobile/controllers/app_controller.dart';
import 'package:mobile/controllers/sms_controller.dart';
import 'package:mobile/graphql/notification_api.dart';
import 'package:mobile/services/local_notification_service.dart';
import 'package:path_provider/path_provider.dart';

@pragma('vm:entry-point')
Future<void> onStart(ServiceInstance service) async {
  final box = GetStorage();
  int lastNotificationId = 0;
  final smsController = SmsController();

  // -----------------------------------------------
  // (1) 기존 1분마다 SMS, 서버 알림
  // -----------------------------------------------
  Timer.periodic(const Duration(minutes: 1), (timer) async {
    // SMS
    await smsController.refreshSms();

    // 서버 알림
    final notiList = await NotificationApi.getNotifications();
    if (notiList.isEmpty) return;

    final displayedStrList = box.read<List<dynamic>>('displayedNotiIds') ?? [];
    final displayedNotiIds = displayedStrList.map((e) => e.toString()).toSet();

    for (final n in notiList) {
      final sid = (n['id'] ?? '').toString();
      if (sid.isEmpty) continue;

      if (displayedNotiIds.contains(sid)) {
        continue;
      }

      final title = n['title'] as String? ?? 'No Title';
      final message = n['message'] as String? ?? '...';
      log('[BackgroundService] show local noti => $title / $message');

      int idInt = lastNotificationId++;
      await LocalNotificationService.showNotification(
        id: idInt,
        title: title,
        body: message,
      );

      // 알림 데이터 저장을 AppController에 요청
      service.invoke('saveNotification', {
        'id': sid,
        'title': title,
        'message': message,
      });

      displayedNotiIds.add(sid);
    }

    // displayedNotiIds 저장
    await box.write('displayedNotiIds', displayedNotiIds.toList());
  });

  // -----------------------------------------------
  // (2) 통화 타이머 관리
  // -----------------------------------------------
  // - service.invoke('startCallTimer', { 'phoneNumber':..., 'callerName': ... })
  //   하면 startCallTimerHandler 호출.
  // - service.invoke('stopCallTimer') 하면 멈춤
  String? ongoingNumber;
  String? ongoingName;
  int ongoingSeconds = 0;
  Timer? callTimer;
  const ONGOING_CALL_NOTI_ID = 9999;

  service.on('startCallTimer').listen((event) async {
    // event: { phoneNumber: '010-...', callerName: '홍길동' }
    final phoneNumber = event?['phoneNumber'] as String? ?? '';
    final callerName = event?['callerName'] as String? ?? '';

    log('[BackgroundService] startCallTimer => $phoneNumber');

    ongoingNumber = phoneNumber;
    ongoingName = callerName.isNotEmpty ? callerName : '';
    ongoingSeconds = 0;

    // 매초 갱신: ongoing 알림 내용 업데이트
    await LocalNotificationService.showOngoingCallNotification(
      id: ONGOING_CALL_NOTI_ID,
      callerName: ongoingName ?? '',
      phoneNumber: ongoingNumber ?? '',
    );
    // 기존 타이머 정리
    callTimer?.cancel();
    callTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      ongoingSeconds++;

      // 만약 UI 쪽에 알림을 보낼 경우:
      service.invoke('updateCallUI', {
        'elapsed': ongoingSeconds,
        'phoneNumber': ongoingNumber,
      });
    });
  });

  service.on('stopCallTimer').listen((event) async {
    log('[BackgroundService] stopCallTimer');
    callTimer?.cancel();
    callTimer = null;
    // ongoing 알림 닫기
    await LocalNotificationService.cancelNotification(ONGOING_CALL_NOTI_ID);
  });

  // service가 stopService 호출되면?
  service.on('stopService').listen((event) async {
    callTimer?.cancel();
    service.stopSelf();

    await LocalNotificationService.cancelNotification(ONGOING_CALL_NOTI_ID);
  });
}
