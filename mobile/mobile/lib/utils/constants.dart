import 'package:intl/intl.dart';

const String APP_VERSION = '0.2.4';
const String APP_NAME = 'KOL_PHONE';
const String APP_DOWNLOAD_LINK =
    'https://jumo-vs8e.onrender.com/download/app.apk';

// 폴더블 기기 모델명 리스트
const List<String> FLIP_MODELS = [
  'SM-F700', // Galaxy Z Flip
  'SM-F707', // Galaxy Z Flip 5G
  'SM-F711', // Galaxy Z Flip 3
  'SM-F721', // Galaxy Z Flip 4
  'SM-F731', // Galaxy Z Flip 5
  'SM-W2022', // China 버전
];

const List<String> FOLD_MODELS = [
  'SM-F900', // Galaxy Fold
  'SM-F907', // Galaxy Fold 5G
  'SM-F916', // Galaxy Z Fold 2
  'SM-F926', // Galaxy Z Fold 3
  'SM-F936', // Galaxy Z Fold 4
  'SM-F946', // Galaxy Z Fold 5
];

String normalizePhone(String raw) {
  final lower = raw.toLowerCase().trim();
  var replaced = lower.replaceAll('+82', '82');
  replaced = replaced.replaceAll(RegExp(r'[^0-9]'), '');
  if (replaced.startsWith('82')) {
    replaced = '0${replaced.substring(2)}';
  } else if (replaced.startsWith('+1')) {
    replaced = replaced.substring(2);
  }

  return replaced;
}

/// 서버에서 받은 dateStr(=epoch string or ISO string)을 DateTime으로 변환
DateTime? parseServerTime(String? dateStr) {
  if (dateStr == null || dateStr.isEmpty) return null;

  // 1) epoch 정수로 파싱 시도
  final maybeEpoch = int.tryParse(dateStr);
  if (maybeEpoch != null) {
    // epoch (ms)
    return DateTime.fromMillisecondsSinceEpoch(maybeEpoch);
  } else {
    // 2) ISO-8601 등 문자열 파싱
    return DateTime.tryParse(dateStr);
  }
}

/// 서버에서 받은 dateStr을 "yyyy-MM-dd HH:mm" 형태로 변환
String formatDateString(String? dateStr) {
  final dt = parseServerTime(dateStr);
  if (dt == null) return dateStr ?? '';

  // 로컬 시간대
  final localDt = dt.toLocal();

  // 원하는 포맷(예: yyyy-MM-dd HH:mm)
  final formatter = DateFormat('yyyy-MM-dd HH:mm');
  return formatter.format(localDt);
}

/// 서버에서 받은 dateStr을 "MM-DD HH:mm" 형태로 변환
String shortDateTime(String? dateStr) {
  final dt = parseServerTime(dateStr);
  if (dt == null) return dateStr ?? '';

  // 로컬 시간대
  final localDt = dt.toLocal();

  // 원하는 포맷(예: MM-DD HH:mm)
  final formatter = DateFormat('MM-dd HH:mm');
  return formatter.format(localDt);
}

/// 서버에서 받은 dateStr을 "MM/DD" 형태로 변환
String formatDateOnly(String? dateStr) {
  final dt = parseServerTime(dateStr);
  if (dt == null) return dateStr ?? '';

  // 로컬 시간대
  final localDt = dt.toLocal();

  // 원하는 포맷(예: MM/DD)
  final formatter = DateFormat('MM/dd');
  return formatter.format(localDt);
}

/// 서버에서 받은 dateStr을 "HH:mm" 형태로 변환
String formatTimeOnly(String? dateStr) {
  final dt = parseServerTime(dateStr);
  if (dt == null) return dateStr ?? '';

  // 로컬 시간대
  final localDt = dt.toLocal();

  // 원하는 포맷(예: HH:mm)
  final formatter = DateFormat('HH:mm');
  return formatter.format(localDt);
}

/// 서버에서 받은 dateStr을 "yyyy년 MM월 DD일" 형태로 변환
String formatKoreanDate(String? dateStr) {
  final dt = parseServerTime(dateStr);
  if (dt == null) return dateStr ?? '';

  // 로컬 시간대
  final localDt = dt.toLocal();

  // 원하는 포맷(예: yyyy년 MM월 DD일)
  final formatter = DateFormat('yyyy년 MM월 dd일');
  return formatter.format(localDt);
}

/// 서버에서 받은 dateStr을 "yyyy년 MM월 DD일 HH:mm" 형태로 변환
String formatKoreanDateTime(String? dateStr) {
  final dt = parseServerTime(dateStr);
  if (dt == null) return dateStr ?? '';

  // 로컬 시간대
  final localDt = dt.toLocal();

  // 원하는 포맷(예: yyyy년 MM월 DD일 HH:mm)
  final formatter = DateFormat('yyyy년 MM월 dd일 HH:mm');
  return formatter.format(localDt);
}

/// 로컬 epoch milliseconds를 UTC epoch milliseconds로 변환
int localEpochToUtcEpoch(int localEpochMs) {
  final localDt = DateTime.fromMillisecondsSinceEpoch(localEpochMs);
  final utcDt = localDt.toUtc();
  return utcDt.millisecondsSinceEpoch;
}

/// UTC epoch milliseconds를 로컬 epoch milliseconds로 변환
int utcEpochToLocalEpoch(int utcEpochMs) {
  final utcDt = DateTime.fromMillisecondsSinceEpoch(utcEpochMs);
  final localDt = utcDt.toLocal();
  return localDt.millisecondsSinceEpoch;
}
