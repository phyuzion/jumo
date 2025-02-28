// lib/controllers/permission_controller.dart
import 'package:permission_handler/permission_handler.dart';

class PermissionController {
  static final List<Permission> essentialPermissions = [
    Permission.phone, // covers CALL_PHONE, READ_PHONE_STATE
    Permission.contacts,
    Permission.sms,
    // If you want readCallLog: Permission.activityRecognition?
    // or some other approach
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
