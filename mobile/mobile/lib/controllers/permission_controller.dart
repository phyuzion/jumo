// lib/controllers/permission_controller.dart
import 'package:permission_handler/permission_handler.dart';

class PermissionController {
  // 모든 필요한 권한 목록 (요청용)
  static final List<Permission> essentialPermissions = [
    Permission.phone, // CALL_PHONE, READ_PHONE_STATE
    Permission.contacts, // READ_CONTACTS
    Permission.sms, // READ_SMS, RECEIVE_SMS
    Permission.notification,
    // If needed, add readCallLog or readPhoneNumbers
  ];

  // 실제로 앱 실행에 필수적인 권한 목록 (SMS 제외)
  static final List<Permission> trulyEssentialPermissions = [
    Permission.phone,
    Permission.contacts,
    Permission.notification,
  ];

  static Future<bool> requestAllEssentialPermissions() async {
    // 모든 권한 요청 (SMS 포함)
    final statuses = await essentialPermissions.request();

    // SMS를 제외한 실제 필수 권한만 확인
    for (final p in trulyEssentialPermissions) {
      if (statuses[p] != PermissionStatus.granted) {
        return false;
      }
    }
    return true;
  }
}
