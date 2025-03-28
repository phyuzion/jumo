import 'package:intl/intl.dart';

const String APP_VERSION = '0.0.5';
const String APP_NAME = 'KOL_PHONE';
const String APP_DOWNLOAD_LINK =
    'https://jumo-vs8e.onrender.com/download/app.apk';

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

// 이건 상단에 만들거나 utils에 둔 후 import
String shortDateTime(String input) {
  DateTime? dt = DateTime.tryParse(input);
  if (dt == null) return input;
  final mmdd =
      '${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  final hhmm =
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  return '$mmdd $hhmm'; // 2줄
}

/// 서버에서 받은 dateStr(=epoch string or ISO string)을
/// "yyyy-MM-dd HH:mm" 형태로 변환
String formatDateString(String? dateStr) {
  if (dateStr == null || dateStr.isEmpty) return '';

  DateTime? dt;

  // 1) epoch 정수로 파싱 시도
  final maybeEpoch = int.tryParse(dateStr);
  if (maybeEpoch != null) {
    // epoch (ms)
    dt = DateTime.fromMillisecondsSinceEpoch(maybeEpoch);
  } else {
    // 2) ISO-8601 등 문자열 파싱
    dt = DateTime.tryParse(dateStr);
  }

  if (dt == null) {
    // 파싱 불가 -> 원본 반환 or 빈 문자열
    return dateStr;
  }

  // 로컬 시간대
  dt = dt.toLocal();

  // 원하는 포맷(예: yyyy-MM-dd HH:mm)
  final formatter = DateFormat('yyyy-MM-dd HH:mm');
  return formatter.format(dt);
}
