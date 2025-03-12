// lib/services/search_service.dart (또는 controllers/search_controller.dart)

import 'package:mobile/graphql/search_api.dart';
import 'package:mobile/models/phone_number_model.dart';
import 'package:mobile/utils/constants.dart';

class SearchRecordsController {
  /// 전화번호 검색 수행 → PhoneNumberModel 리턴
  static Future<PhoneNumberModel?> searchPhone(String rawPhone) async {
    final norm = normalizePhone(rawPhone);
    // 실제 서버 호출
    final data = await SearchApi.getPhoneNumber(norm);
    return data; // null 이면 결과 없음
  }
}
