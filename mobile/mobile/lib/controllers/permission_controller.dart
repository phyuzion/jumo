// lib/controllers/permission_controller.dart
import 'package:permission_handler/permission_handler.dart';

class PermissionController {
  static final List<Permission> essentialPermissions = [
    Permission.phone, // CALL_PHONE, READ_PHONE_STATE
    Permission.contacts, // READ_CONTACTS
    Permission.sms, // READ_SMS, RECEIVE_SMS
    // If needed, add readCallLog or readPhoneNumbers
  ];

  static Future<bool> requestAllEssentialPermissions() async {
    final statuses = await essentialPermissions.request();
    for (final p in essentialPermissions) {
      if (statuses[p] != PermissionStatus.granted) {
        return false;
      }
    }
    return true;
  }
}
