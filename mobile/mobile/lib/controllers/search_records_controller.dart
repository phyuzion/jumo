// lib/services/search_service.dart (또는 controllers/search_controller.dart)

import 'package:mobile/graphql/search_api.dart';
// import 'package:mobile/graphql/today_record_api.dart';
import 'package:mobile/models/phone_number_model.dart';
import 'package:mobile/utils/constants.dart';
import 'package:mobile/models/today_record.dart';

class SearchRecordsController {
  /// 전화번호 검색 수행 → PhoneNumberModel 리턴 (이제 todayRecords 포함)
  static Future<PhoneNumberModel?> searchPhone(
    String rawPhone, {
    bool isRequested = false,
  }) async {
    final norm = normalizePhone(rawPhone);
    // 실제 서버 호출
    final data = await SearchApi.getPhoneNumber(norm, isRequested: isRequested);
    return data; // null 이면 결과 없음
  }

  // static Future<List<TodayRecord>> searchTodayRecord(String phoneNumber) async {
  //   final norm = normalizePhone(phoneNumber);
  //   // 실제 서버 호출
  //   final records = await TodayRecordApi.getTodayRecord(norm);
  //   return records;
  // }
}
