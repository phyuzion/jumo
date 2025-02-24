// lib/core/services/permission_service.dart

import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  static Future<void> requestNecessaryPermissions() async {
    final permissions = [
      Permission.phone,
      Permission.contacts,
      // 필요시 다른 권한도
    ];
    await permissions.request();
    // 여기서 만약 거부당하면 사용자에게 재요청 or 가이드
  }
}
