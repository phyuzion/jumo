import 'dart:developer';
import 'dart:io';
import 'package:flutter/foundation.dart'; // kIsWeb 검사 시 필요
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:app_installer/app_installer.dart';

import 'package:mobile/utils/constants.dart';
import 'package:mobile/graphql/version_api.dart'; // 방금 만든 VersionApi

class UpdateController {
  /// 1) 서버 APK 버전 조회 -> 내 앱 버전(APP_VERSION)과 비교
  Future<void> checkVersion(bool autoInstall) async {
    try {
      final serverVersion = await VersionApi.getApkVersion();
      log('checkVersion local=$APP_VERSION, server=$serverVersion');

      if (serverVersion.isEmpty) {
        log('서버 버전 정보가 비어있음. 업데이트 건너뜀.');
        return;
      }

      // 간단 비교: 서버가 더 크면 업데이트
      // (실제론 버전 문자열 파싱 ex. 1.2.3 -> int list 비교가 안전)
      if (serverVersion != APP_VERSION) {
        log('업데이트 필요! server=$serverVersion vs local=$APP_VERSION');
        if (autoInstall) await downloadAndInstallApk(); // 다운로드 & 설치
      } else {
        log('업데이트 불필요. 이미 최신 버전.');
      }
    } catch (e) {
      log('checkVersion error: $e');
    }
  }

  /// 2) APK 다운로드 -> 설치
  Future<void> downloadAndInstallApk() async {
    // 서버에서 APK 다운로드 링크 (Render 등)
    // ex. "https://<your-host>/download/app.apk"
    final url = Uri.parse(APP_DOWNLOAD_LINK);

    if (kIsWeb) {
      // 웹은 APK 설치 불가능, 예외 or 건너뛰기
      log('웹 환경에서는 APK 설치 불가');
      return;
    }

    try {
      log('Downloading APK from $APP_DOWNLOAD_LINK ...');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final directory = await getExternalStorageDirectory();
        if (directory != null) {
          final filePath = '${directory.path}/app.apk';
          final file = File(filePath);

          await file.writeAsBytes(response.bodyBytes);

          if (await file.exists()) {
            log('APK downloaded -> $filePath, Installing...');
            // Launch the installer to install the APK
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
