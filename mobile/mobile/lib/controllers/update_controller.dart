// update_controller.dart

import 'dart:developer';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:app_installer/app_installer.dart';

import 'package:mobile/utils/constants.dart';
import 'package:mobile/graphql/version_api.dart';

class UpdateController {
  /// 서버 버전만 단순 조회
  /// - 예: "1.2.3" 반환, 서버 응답 없으면 ""(빈문자)
  Future<String> getServerVersion() async {
    try {
      final serverVersion = await VersionApi.getApkVersion();
      log('[UpdateController] serverVersion=$serverVersion');
      return serverVersion;
    } catch (e) {
      log('getServerVersion error: $e');
      return '';
    }
  }

  /// APK 다운로드 & 설치
  Future<void> downloadAndInstallApk() async {
    if (kIsWeb) {
      log('웹 환경에서는 APK 설치 불가');
      return;
    }

    final url = Uri.parse(APP_DOWNLOAD_LINK);
    log('Downloading APK from $APP_DOWNLOAD_LINK ...');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final directory = await getExternalStorageDirectory();
        if (directory != null) {
          final filePath = '${directory.path}/app.apk';
          final file = File(filePath);

          await file.writeAsBytes(response.bodyBytes);

          if (await file.exists()) {
            log('APK downloaded -> $filePath, Installing...');
            AppInstaller.installApk(filePath);
          } else {
            log('File does not exist after saving? path=$filePath');
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
