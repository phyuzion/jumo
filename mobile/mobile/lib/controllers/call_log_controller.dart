import 'dart:async';
import 'dart:collection';
import 'dart:developer';

import 'package:call_e_log/call_log.dart';
import 'package:get_storage/get_storage.dart';
import 'package:mobile/utils/app_event_bus.dart';
import 'package:mobile/graphql/log_api.dart';

class CallLogController {
  final box = GetStorage();
  static const storageKey = 'callLogs';

  /// 작업 대기열
  final Queue<Function> _taskQueue = Queue();

  /// 현재 실행 중인지
  bool _busy = false;

  /// ============ 외부에서 부르는 메인 메서드 ============
  /// 디바이스 CallLog (200개) 읽어 로컬저장 + 서버업로드
  Future<void> refreshCallLogs() async {
    // 1) 작업을 "익명함수" 형태로 큐에 넣고,
    //    그 함수 안에서 실제 로직(로컬저장 + 서버업로드)을 수행
    final completer = Completer<void>();

    _taskQueue.add(() async {
      try {
        final callEntries = await CallLog.get();
        final take200 = callEntries.take(200);

        final newList = <Map<String, dynamic>>[];
        for (final e in take200) {
          final map = {
            'number': e.number ?? '',
            'name': e.name ?? '',
            'callType':
                e.callType?.name ?? '', // "incoming"/"outgoing"/"missed"
            'timestamp': e.timestamp ?? 0,
          };
          newList.add(map);
        }

        // 로컬 저장
        await box.write(storageKey, newList);
        appEventBus.fire(CallLogUpdatedEvent());

        // 서버 업로드
        await _uploadToServer(newList);

        // 완료
        completer.complete();
      } catch (e, st) {
        log('refreshCallLogs error: $e\n$st');
        completer.completeError(e, st);
      }
    });

    // 2) 만약 현재 실행중이 아니라면, 처리 시작
    _processQueue();

    // 3) 외부에서 대기할 수 있게 future 반환
    return completer.future;
  }

  /// 내부: 큐 처리
  void _processQueue() {
    // 이미 실행 중이면 대기
    if (_busy) return;
    if (_taskQueue.isEmpty) return;

    _busy = true;
    final task = _taskQueue.removeFirst();

    // 실제 실행
    Future(() async {
      await task();
      _busy = false;
      // 다음 작업 있으면 진행
      if (_taskQueue.isNotEmpty) {
        _processQueue();
      }
    });
  }

  /// 내부: 서버에 업로드
  Future<void> _uploadToServer(List<Map<String, dynamic>> localList) async {
    final logsForServer =
        localList.map((m) {
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
      await LogApi.updateCallLog(logsForServer);
    } catch (e) {
      log('통화 로그 업로드 실패: $e');
    }
  }

  /// 로컬 저장된 목록 읽기
  List<Map<String, dynamic>> getSavedCallLogs() {
    final list = box.read<List>(storageKey) ?? [];
    return list.map((e) => Map<String, dynamic>.from(e)).toList();
  }
}
