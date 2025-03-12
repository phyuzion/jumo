import 'dart:convert';
import 'dart:io';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:app_installer/app_installer.dart';
import 'dart:developer';

class UpdateController {
  final box = GetStorage();

  Future<void> checkVersion() async {
    log('check Version');
  }

  Future<void> downloadAndInstallApk() async {
    final url = Uri.parse('download URL');

    try {
      log('Downloading APK...');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final directory = await getExternalStorageDirectory();
        if (directory != null) {
          final filePath = '${directory.path}/ssoft_premium.apk';
          File file = File(filePath);

          await file.writeAsBytes(response.bodyBytes);

          if (await file.exists()) {
            log('APK downloaded successfully. Installing...');
            // Launch the installer app to install the APK
            AppInstaller.installApk(filePath);
          } else {
            log('File does not exist at the specified path.');
          }
        } else {
          log('External storage directory is null.');
        }
      } else {
        log('Failed to download APK. Status code: ${response.statusCode}');
      }
    } catch (e) {
      log('Error downloading and installing APK: $e');
    }
  }
}
