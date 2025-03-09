import 'dart:developer';

import 'package:call_e_log/call_log.dart';
import 'package:get_storage/get_storage.dart';
import 'package:mobile/graphql/apis.dart'; // JumoGraphQLApi
import 'package:mobile/utils/app_event_bus.dart';

class CallLogController {
  final box = GetStorage();

  /// key for storage
  static const storageKey = 'callLogs';

  /// 최신 200개 통화기록을 가져와 로컬에 저장 후, 곧바로 서버에 업로드 시도
  Future<List<Map<String, dynamic>>> refreshCallLogs() async {
    // 1) 디바이스에서 call log 200개 가져오기
    final callLogEntry = await CallLog.get();
    final callLogTake200 = callLogEntry.take(200);

    final callLogList = <Map<String, dynamic>>[];
    for (final e in callLogTake200) {
      final map = {
        'number': e.number ?? '',
        'name': e.name ?? '',
        // 'incoming' | 'outgoing' | 'missed'
        'callType': e.callType?.name ?? '',
        'timestamp': e.timestamp ?? 0,
      };
      callLogList.add(map);
    }

    // 2) 로컬 저장
    await box.write(storageKey, callLogList);

    // 이벤트
    appEventBus.fire(CallLogUpdatedEvent());

    // 3) 서버에 업로드 (로그인되어 있으면)
    await _uploadToServer(callLogList);

    return callLogList;
  }

  /// 서버 업로드 부분
  Future<void> _uploadToServer(List<Map<String, dynamic>> localLogs) async {
    final accessToken = JumoGraphQLApi.accessToken;
    if (accessToken == null) {
      // 아직 로그인 안됨 => 업로드 스킵 or 로그만
      log('[CallLogController] Not logged in. Skip upload.');
      return;
    }
    // userId 필요. (로그인 시 어딘가에 저장해뒀다고 가정)
    final userId = box.read<String>('myUserId') ?? '';
    if (userId.isEmpty) {
      log('[CallLogController] myUserId is empty. Skip upload.');
      return;
    }

    // 1) GraphQL에 맞게 변환
    // callType: 'incoming' => 'IN', 'outgoing' => 'OUT', 'missed' => 'MISS'
    // time => epoch string
    final logsForServer =
        localLogs.map((m) {
          final phone = m['number'] as String? ?? '';
          final tsString = (m['timestamp'] ?? '').toString();
          final ctype = m['callType'] as String? ?? '';
          String serverType;
          if (ctype == 'incoming') {
            serverType = 'IN';
          } else if (ctype == 'outgoing') {
            serverType = 'OUT';
          } else {
            serverType = 'MISS';
          }
          return {
            'phoneNumber': phone,
            'time': tsString,
            'callType': serverType,
          };
        }).toList();

    // 2) 업로드
    try {
      final ok = await JumoGraphQLApi.updatePhoneLog(
        userId: userId,
        logs: logsForServer,
      );
      if (ok) {
        log('[CallLogController] 통화 로그 서버 업로드 성공');
      } else {
        log('[CallLogController] 통화 로그 서버 업로드 실패(서버 false)');
      }
    } catch (e) {
      log('[CallLogController] 업로드 중 에러: $e');
    }
  }

  /// get_storage 에서 이전 목록 읽기
  List<Map<String, dynamic>> getSavedCallLogs() {
    final list = box.read<List>(storageKey) ?? [];
    return list.map((e) => Map<String, dynamic>.from(e)).toList();
  }
}
