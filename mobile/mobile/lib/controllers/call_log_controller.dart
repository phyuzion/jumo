// call_log_controller.dart
import 'dart:async';
import 'dart:collection';
import 'dart:developer';
import 'package:call_e_log/call_log.dart'; // 예: call_e_log 패키지
import 'package:get_storage/get_storage.dart';
import 'package:mobile/utils/app_event_bus.dart';
import 'package:mobile/graphql/log_api.dart';

class CallLogController {
  final box = GetStorage();
  static const storageKey = 'callLogs';

  final Queue<Function> _taskQueue = Queue();
  bool _busy = false;

  /// 통화 목록 새로 읽어서 -> 로컬 DB에 저장 -> 서버 업로드
  Future<void> refreshCallLogs() async {
    final completer = Completer<void>();

    _taskQueue.add(() async {
      try {
        final callEntries = await CallLog.get(); // call_e_log 등에서 가져온 통화내역
        final take200 = callEntries.take(200);

        final newList = <Map<String, dynamic>>[];
        for (final e in take200) {
          log('e: ${e.number} time : ${e.timestamp}');
          final map = {
            'number': e.number ?? '',
            'callType':
                e.callType?.name ?? '', // 'incoming','outgoing','missed' 등
            'timestamp': e.timestamp ?? 0, // epoch ms
            // 'name': e.name ?? '',  // <-- 이전에는 여기서 name을 저장했지만 제거
          };
          newList.add(map);
        }

        // (A) 로컬 DB에 저장
        await box.write(storageKey, newList);
        // 이벤트 (RecentCallsScreen 등에서 감지해서 UI 갱신)
        appEventBus.fire(CallLogUpdatedEvent());

        // (B) 서버 업로드
        await _uploadToServer(newList);

        completer.complete();
      } catch (e, st) {
        log('refreshCallLogs error: $e\n$st');
        completer.completeError(e, st);
      }
    });

    _processQueue();
    return completer.future;
  }

  /// 내부: 큐 처리(1개씩 순차 실행)
  void _processQueue() {
    if (_busy) return;
    if (_taskQueue.isEmpty) return;

    _busy = true;
    final task = _taskQueue.removeFirst();

    Future(() async {
      await task();
      _busy = false;
      if (_taskQueue.isNotEmpty) {
        _processQueue();
      }
    });
  }

  /// (B) 서버 업로드
  Future<void> _uploadToServer(List<Map<String, dynamic>> localList) async {
    // localList엔 "number","callType","timestamp"만 존재
    final logsForServer =
        localList.map((m) {
          // callType( 'incoming','outgoing','missed' ) → 서버에서 원하는 값
          final rawType = (m['callType'] as String).toLowerCase();
          String serverType;
          switch (rawType) {
            case 'incoming':
              serverType = 'IN';
              break;
            case 'outgoing':
              serverType = 'OUT';
              break;
            case 'missed':
              serverType = 'MISS';
              break;
            default:
              serverType = 'UNKNOWN';
          }
          return <String, dynamic>{
            'phoneNumber': m['number'] ?? '',
            'time': (m['timestamp'] ?? '').toString(), // epoch → string
            'callType': serverType,
          };
        }).toList();

    try {
      // 실제 GraphQL API 호출
      await LogApi.updateCallLog(logsForServer);
    } catch (e) {
      log('통화 로그 업로드 실패: $e');
    }
  }

  /// 외부: 로컬에 저장된 통화 목록 불러오기
  /// - 여기엔 'number','callType','timestamp'만 있음
  List<Map<String, dynamic>> getSavedCallLogs() {
    final list = box.read<List>(storageKey) ?? [];
    return list.map((e) => Map<String, dynamic>.from(e)).toList();
  }
}
