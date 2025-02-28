// lib/controllers/app_controller.dart
import 'dart:developer';
import 'package:get_storage/get_storage.dart';
import 'package:mobile/controllers/permission_controller.dart';
import 'package:mobile/services/native_methods.dart';

class AppController {
  final box = GetStorage();
  bool allPermissionsGranted = false;

  Future<void> initializeApp() async {
    // 1) GetStorage init
    await GetStorage.init();

    // 2) 필수 권한 요청
    allPermissionsGranted =
        await PermissionController.requestAllEssentialPermissions();
    if (!allPermissionsGranted) {
      log('필수 권한 거부 => 앱 기능 제한 or 종료');
      // TODO: show a “permissions needed” screen or exit
      return;
    }

    // 3) 핸드폰 번호 가져오기
    final myNumber = await NativeMethods.getMyPhoneNumber();
    log('My number: $myNumber');
    box.write('my_number', myNumber);

    // 4) 로그인 or 기타 로직
  }
}
