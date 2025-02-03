import 'package:fluttertoast/fluttertoast.dart';
import 'dart:developer';

const String APP_VERSION = '1.0.0';
const String APP_NAME = 'TIGER_LAB_JUMO';
const String LATEST_TAB = '최근 기록';
const String ACCOUNT_TAB = '계정';
const String CALL_TAB = '수신기록';
const String SEARCH_TAB = '검색';
const String CHECK_PERMISSION = '로딩을 위해 누르세요.';

const String LOGIN = '로그인';
const String LOGOUT = '로그아웃';

const String REPORT_SUCCESS_MESSAGE = '신고 완료';
const String REPORT_FAIL_MESSAGE = '아직 신고할 수 없습니다.';

const String CONTROLLER_PORT = 'MAIN_PORT';
const String OVERLAY_PORT = 'OVERLAY_PORT';
const String SETTING_PORT = 'SETTING_PORT';

const String OVERLAY_ID = 'GxG_OVERLAY';
const String OVERLAY_STATUS_REFRESH_MESSAGE = 'OVERLAY_STATUS_REFRESH_CHANGE';

const String LOGIN_URL = 'https://tigergxg.com/account/login';
const String REPORT_SET_URL = 'https://tigergxg.com/account/publish';
const String REPORT_GET_URL = 'https://tigergxg.com/account/reports';
const String NICK_URL = 'https://tigergxg.com/account/nick';
const String PROFILE_SET_URL = 'https://tigergxg.com/account/setsetting';
const String PROFILE_GET_URL = 'https://tigergxg.com/account/getsetting';
const String VERSION_URL = 'https://tigergxg.com/account/version';
const String DOWNLOAD_URL = 'https://tigergxg.com/account/download/ssoft.apk';

const String USER_ID_KEY = 'USER_ID_KEY';
const String USER_PHONE_KEY = 'USER_PHONE_KEY';
const String USER_NAME = 'NAME';
const String USER_EXPIRE = 'USER_EXPIRE';

const String GRAPHQL_URL = "https://jumo-vs8e.onrender.com/graphql";

const bool DEBUG = true;

int parseInt(String str) {
  int? parsedValue = int.tryParse(str);

  if (parsedValue != null) {
    return parsedValue;
  } else {
    return 0;
  }
}

double parseDouble(String str) {
  double? parsedValue = double.tryParse(str);

  if (parsedValue != null) {
    return parsedValue;
  } else {
    return 0;
  }
}

// KST (UTC+9)로 변환하여 "YYYY-MM-DD" 형식으로 포맷하는 헬퍼 함수
String formatKST(String timestampStr) {
  try {
    log('원본 timestamp: $timestampStr');
    // 전달받은 문자열을 정수로 변환 (밀리초 단위)
    final ms = parseInt(timestampStr);
    // UTC 기준으로 DateTime 객체 생성
    final dt = DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
    // KST는 UTC+9
    final kst = dt.add(const Duration(hours: 9));
    final year = kst.year.toString();
    final month = kst.month.toString().padLeft(2, '0');
    final day = kst.day.toString().padLeft(2, '0');
    return "$year-$month-$day";
  } catch (e) {
    log('has error : $timestampStr, error: $e');
    return timestampStr;
  }
}

void showToast(String msg) {
  Fluttertoast.showToast(
    msg: msg,
    toastLength: Toast.LENGTH_SHORT,
    gravity: ToastGravity.BOTTOM,
  );
}

bool isNumeric(String str) {
  // Attempt to parse the string as a number
  var parsed = num.tryParse(str);
  // If the parsing was successful and the parsed value is not null,
  // then the string is a number
  return parsed != null;
}
