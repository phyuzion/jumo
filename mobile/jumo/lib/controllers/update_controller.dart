import 'dart:convert';
import 'dart:io';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:app_installer/app_installer.dart';
import 'dart:developer';

import '../util/constants.dart';

class UpdateController {
  final box = GetStorage();

  Future<void> checkVersion() async {
    log('check Version');
    String id = box.read(USER_ID_KEY);
    String version = APP_VERSION;

    var headers = {'Content-Type': 'application/json'};
    var request = http.Request('GET', Uri.parse(VERSION_URL));
    request.body = json.encode({'id': id});
    request.headers.addAll(headers);

    http.StreamedResponse response = await request.send();

    if (response.statusCode == 200) {
      final responseString = await response.stream.bytesToString();

      final result = jsonDecode(responseString);
      log('version : $result');
      if (result.containsKey('VERSION')) {
        final latestVersion = result['VERSION'];
        if (latestVersion.toString() != version) {
          log('Request update');
          showToast('최신 버전을 다운로드 후 설치 요청합니다.');
          downloadAndInstallApk();
        } else {
          log('latest version');
          showToast('최신 버전입니다.');
        }
      } else {
        log('Can not update.');
        showToast('업데이트할 수 없습니다. 관리자에게 문의하세요.');
      }
    } else {
      log('Can not update.');
      showToast('업데이트할 수 없습니다. 관리자에게 문의하세요.');
    }
  }

  Future<void> downloadAndInstallApk() async {
    final url = Uri.parse(DOWNLOAD_URL);

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
            showToast('다운로드 할 수 없습니다. 관리자에게 문의하세요.');
          }
        } else {
          log('External storage directory is null.');
          showToast('다운로드 할 수 없습니다. 관리자에게 문의하세요.');
        }
      } else {
        log('Failed to download APK. Status code: ${response.statusCode}');
        showToast('다운로드 할 수 없습니다. 관리자 문의 : ${response.statusCode}');
      }
    } catch (e) {
      log('Error downloading and installing APK: $e');
      showToast('다운로드 할 수 없습니다. 관리자 문의 : $e');
    }
  }
}
