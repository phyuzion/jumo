// lib/controllers/app_controller.dart
import 'dart:developer';

import 'package:get_storage/get_storage.dart';
import '../services/native_methods.dart';

class AppController {
  final box = GetStorage();

  Future<void> initializeApp() async {
    // 1) GetStorage init
    await GetStorage.init();

    // 2) 핸드폰 번호 가져오기
    final myNumber = await NativeMethods.getMyPhoneNumber();
    log('My number: $myNumber');
    box.write('my_number', myNumber);

    // 3) 로그인 체크 or 자동로그인?
    // 4) 주소록 동기화? (추가구현)
  }
}
