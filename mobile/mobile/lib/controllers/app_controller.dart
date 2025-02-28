// lib/controllers/app_controller.dart
import 'dart:developer';
import 'package:mobile/controllers/permission_controller.dart';
import 'package:mobile/services/native_methods.dart';
import 'package:get_storage/get_storage.dart';

class AppController {
  Future<bool> checkEssentialPermissions() async {
    return await PermissionController.requestAllEssentialPermissions();
  }

  Future<void> initializeApp() async {
    await GetStorage.init();
    final myNumber = await NativeMethods.getMyPhoneNumber();
    log('myNumber=$myNumber');
    // etc...
  }
}
