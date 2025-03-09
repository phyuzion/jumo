// lib/services/app_background_service.dart

import 'dart:async';
import 'dart:developer';
import 'package:flutter_background_service/flutter_background_service.dart';

// 예: call log / sms / contacts 컨트롤러들 import
import 'package:mobile/controllers/call_log_controller.dart';
import 'package:mobile/controllers/sms_controller.dart';
import 'package:mobile/controllers/contacts_controller.dart';

/// 최상위(또는 static) 함수: Service 시작 시 호출되는 entry
@pragma('vm:entry-point')
Future<void> onStart(ServiceInstance service) async {
  // 안드로이드인 경우, Foreground Service 로 등록
  if (service is AndroidServiceInstance) {
    service.setAsForegroundService();
    service.setForegroundNotificationInfo(
      title: "Data Sync Service",
      content: "Synchronizing call log, sms, contacts every 10 seconds...",
    );
  }

  // 컨트롤러들(실제 diff 로직)
  final callLogController = CallLogController();
  final smsController = SmsController();
  final contactsController = ContactsController();

  // 10분 타이머
  Timer.periodic(const Duration(seconds: 10), (timer) async {
    await callLogController.refreshCallLogs();
    await smsController.refreshSms();
    await contactsController.refreshContactsWithDiff();

    log('timer called');
  });

  // “stopService” event 수신 => self stop
  service.on('stopService').listen((event) {
    service.stopSelf();
  });
}
