import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:flutter_sms_intellect/flutter_sms_intellect.dart';
import 'package:hive_ce/hive.dart';
import 'package:mobile/graphql/log_api.dart';
import 'package:mobile/utils/constants.dart';

class SmsController {
  static const String _storageKey = 'sms_logs';
  static const String _lastSyncKey = 'lastSmsUploadTimestamp';
  Box get _smsLogBox => Hive.box(_storageKey);
  Box get _settingsBox => Hive.box('settings');

  /// 최신 SMS 가져와 변경된 내역만 서버 업로드
  Future<void> refreshSms() async {
    try {
      // 1. 마지막 업로드 시간 확인
      final int lastUploadTimestamp =
          _settingsBox.get(_lastSyncKey, defaultValue: 0) as int;

      // 2. 최신 SMS 읽기
      final messages = await SmsInbox.getAllSms(count: 30); // Inbox만 읽는 한계 인지

      // 3. 메시지 처리 및 로컬 캐시용 목록 생성
      final List<Map<String, dynamic>> processedSmsList = []; // 로컬 저장용 전체 목록
      int latestTimestampInFetched = lastUploadTimestamp; // 읽어온 것 중 최신 시간

      for (final msg in messages) {
        final address = normalizePhone(msg.address ?? '');
        final body = msg.body ?? '';
        final dateMillis = localEpochToUtcEpoch(msg.date ?? 0);
        final type = msg.type?.toString() ?? 'UNKNOWN';

        if (address.isNotEmpty && dateMillis > 0) {
          // 날짜 유효성 체크 추가
          final smsMap = {
            'address': address,
            'body': body,
            'date': dateMillis,
            'type': type,
          };
          processedSmsList.add(smsMap);
          if (dateMillis > latestTimestampInFetched) {
            latestTimestampInFetched = dateMillis;
          }
        }
      }
      // 로컬 캐시는 항상 최신 30개로 업데이트 (기존 방식)
      await _smsLogBox.put('logs', jsonEncode(processedSmsList));

      // 4. 새로 업로드할 메시지 필터링
      final List<Map<String, dynamic>> newSmsToUpload =
          processedSmsList.where((sms) {
            return (sms['date'] as int) > lastUploadTimestamp;
          }).toList();

      // 5. 새 메시지 업로드 및 마지막 타임스탬프 업데이트
      if (newSmsToUpload.isNotEmpty) {
        // 업로드 전 시간순 정렬 (오래된 것부터)
        newSmsToUpload.sort(
          (a, b) => (a['date'] as int).compareTo(b['date'] as int),
        );
        // 업로드할 배치 중 가장 최신 타임스탬프 찾기
        final int latestTimestampInNewBatch =
            newSmsToUpload.last['date'] as int;

        final smsForServer = prepareSmsForServer(newSmsToUpload);
        if (smsForServer.isNotEmpty) {
          try {
            bool uploadSuccess = await LogApi.updateSMSLog(smsForServer);
            if (uploadSuccess) {
              await _settingsBox.put(_lastSyncKey, latestTimestampInNewBatch);
            }
          } catch (uploadError) {
            log('[SmsController] LogApi.updateSMSLog FAILED: $uploadError');
          }
        }
      }
    } catch (e, st) {
      log('[SmsController] refreshSms error: $e\n$st');
    }
  }

  List<Map<String, dynamic>> prepareSmsForServer(
    List<Map<String, dynamic>> localSms,
  ) {
    return localSms.map((m) {
      final phone = m['address'] as String? ?? '';
      final content = m['body'] as String? ?? '';
      final timeStr = (m['date'] ?? 0).toString(); // epoch(int) -> string
      final smsType = (m['type'] ?? '').toString();

      return {
        'phoneNumber': phone,
        'time': timeStr,
        'content': content,
        'smsType': smsType,
      };
    }).toList();
  }
}
