// lib/controllers/call_log_controller.dart
import 'dart:developer';

import 'package:call_e_log/call_log.dart';
import 'package:get_storage/get_storage.dart';

import 'package:mobile/utils/app_event_bus.dart';

class CallLogController {
  final box = GetStorage();

  /// key for storage
  static const storageKey = 'callLogs';

  Future<List<Map<String, dynamic>>> refreshCallLogs() async {
    final callLogEntry = await CallLog.get();
    final callLogTake200 = callLogEntry.take(200);

    final callLogList = <Map<String, dynamic>>[];
    for (final e in callLogTake200) {
      final map = {
        'number': e.number ?? '',
        'name': e.name ?? '',
        'callType': e.callType?.name ?? '',
        'timestamp': e.timestamp ?? 0,
      };
      callLogList.add(map);
    }

    await box.write(storageKey, callLogList);

    appEventBus.fire(CallLogUpdatedEvent());

    return callLogList;
  }

  /// get_storage 에서 이전 목록 읽기
  List<Map<String, dynamic>> getSavedCallLogs() {
    final list = box.read<List>(storageKey) ?? [];
    return list.map((e) => Map<String, dynamic>.from(e)).toList();
  }
}
