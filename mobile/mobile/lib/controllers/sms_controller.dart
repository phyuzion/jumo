import 'dart:async';
import 'dart:collection';
import 'dart:developer';

import 'package:flutter_sms_intellect/flutter_sms_intellect.dart';
import 'package:get_storage/get_storage.dart';
import 'package:mobile/graphql/log_api.dart';

class SmsController {
  final box = GetStorage();
  static const storageKey = 'smsLogs';

  // (A) 작업 큐
  final Queue<Function> _taskQueue = Queue();
  // (B) 실행 중 여부
  bool _busy = false;

  /// 최신 200개 SMS 가져와 로컬 저장 + 서버 업로드
  Future<void> refreshSms() async {
    // 1) Future와 연결될 Completer
    final completer = Completer<void>();

    // 2) 작업(익명함수) 정의 후 큐에 삽입
    _taskQueue.add(() async {
      try {
        // =========== 실제 로직 시작 ===========
        final messages = await SmsInbox.getAllSms(count: 10);
        final smsList = <Map<String, dynamic>>[];

        for (final msg in messages) {
          final map = {
            'address': msg.address ?? '',
            'body': msg.body ?? '',
            'date': msg.date ?? 0, // epoch
            'type': msg.type ?? '', // 1=inbox,2=sent
          };
          smsList.add(map);
        }

        // 2) 로컬 저장
        await box.write(storageKey, smsList);

        // 3) 서버 업로드
        await _uploadToServer(smsList);

        // 완료
        completer.complete();
      } catch (e, st) {
        // 에러 시 completer에 에러 전달
        completer.completeError(e, st);
      }
    });

    // 3) 큐 처리 시도
    _processQueue();

    // 4) 외부에서 await 가능
    return completer.future;
  }

  /// 내부: 큐 처리 (동시에 하나씩)
  void _processQueue() {
    if (_busy) return; // 이미 실행 중이면 아무것도 안 함
    if (_taskQueue.isEmpty) return; // 큐가 비어있으면 종료

    _busy = true;
    final task = _taskQueue.removeFirst();

    // 실제 실행
    Future(() async {
      await task(); // 위에서 정의한 익명함수 실행
      _busy = false;
      // 다음 작업이 남았으면 재귀 호출
      if (_taskQueue.isNotEmpty) {
        _processQueue();
      }
    });
  }

  /// 서버 업로드
  Future<void> _uploadToServer(List<Map<String, dynamic>> localSms) async {
    final smsForServer =
        localSms.map((m) {
          final phone = m['address'] as String? ?? '';
          final content = m['body'] as String? ?? '';
          final timeStr = (m['date'] ?? '').toString();
          final smsType = (m['type'] ?? '').toString();

          return {
            'phoneNumber': phone,
            'time': timeStr,
            'content': content,
            'smsType': smsType,
          };
        }).toList();

    try {
      await LogApi.updateSMSLog(smsForServer);
    } catch (e) {
      log('[SmsController] 업로드 중 에러: $e');
    }
  }

  /// 로컬에 저장된 smsLogs 읽기
  List<Map<String, dynamic>> getSavedSms() {
    final list = box.read<List>(storageKey) ?? [];
    return list.map((e) => Map<String, dynamic>.from(e)).toList();
  }
}
