// lib/controllers/permission_controller.dart
import 'package:permission_handler/permission_handler.dart';

class PermissionController {
  /// 안드로이드에서 필요한 “7개” 권한.
  /// phone_state, contacts, sms 정도는 permission_handler에서 자동 매핑 가능.
  /// READ_CALL_LOG, READ_PHONE_NUMBERS 는 별도 권한으로 필요할 수도 있음.
  static final List<Permission> essentialPermissions = [
    Permission.phone, // covers CALL_PHONE, READ_PHONE_STATE
    Permission.contacts, // READ_CONTACTS
    Permission.sms, // READ_SMS, RECEIVE_SMS
    // If we explicitly want READ_CALL_LOG => Permission.contacts might not cover it
    // If we want READ_PHONE_NUMBERS => might also do .phone or separate
  ];

  /// 모든 필수 권한 요청
  /// 반환: true = 전부 허용, false = 하나라도 거부
  static Future<bool> requestAllEssentialPermissions() async {
    final statuses = await essentialPermissions.request();
    for (final perm in essentialPermissions) {
      if (statuses[perm] != PermissionStatus.granted) {
        return false;
      }
    }
    return true;
  }
}
