import 'dart:developer';
import 'dart:convert';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io' show Platform;

import 'client.dart';

/// 사용자 설정 관련 API
class SettingApi {
  // ==================== setUserSetting ====================
  static const String _setUserSettingMutation = r'''
    mutation setUserSetting($settings: String!) {
      setUserSetting(settings: $settings)
    }
  ''';

  /// 사용자 설정 저장
  ///
  /// Map을 JSON 문자열로 변환하여 서버에 저장합니다.
  ///
  /// 사용 예시:
  /// ```dart
  /// final settingsMap = {
  ///   'deviceInfo': {
  ///     'model': 'SM-G970N',
  ///     'osVersion': 'Android 13',
  ///   },
  ///   'appVersion': '0.2.3',
  ///   'lastUpdateTime': DateTime.now().millisecondsSinceEpoch,
  /// };
  ///
  /// final success = await SettingApi.setUserSetting(settingsMap);
  /// ```
  static Future<bool> setUserSetting(Map<String, dynamic> settingsMap) async {
    try {
      final client = GraphQLClientManager.client;
      final token = await GraphQLClientManager.accessToken;
      if (token == null) {
        log(
          '[SettingApi.setUserSetting] No access token found, user not logged in',
        );
        return false;
      }

      // Map을 JSON 문자열로 변환
      final settingsJson = jsonEncode(settingsMap);

      final options = MutationOptions(
        document: gql(_setUserSettingMutation),
        variables: {'settings': settingsJson},
      );

      final result = await client.mutate(options);
      await GraphQLClientManager.handleExceptions(result);

      if (result.hasException) {
        log('[SettingApi.setUserSetting] Error: ${result.exception}');
        return false;
      }

      final success = result.data?['setUserSetting'] ?? false;
      return success;
    } catch (e) {
      log('[SettingApi.setUserSetting] Exception: $e');
      return false;
    }
  }

  /// 디바이스 정보와 앱 버전을 저장합니다.
  ///
  /// 로그인 성공 후 호출합니다.
  static Future<bool> saveDeviceInfo({required String appVersion}) async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      final Map<String, dynamic> deviceData = {};

      // 플랫폼에 따라 다른 정보 수집
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        deviceData['model'] = androidInfo.model;
        deviceData['brand'] = androidInfo.brand;
        deviceData['androidVersion'] = androidInfo.version.release;
        deviceData['sdkVersion'] = androidInfo.version.sdkInt.toString();
        deviceData['device'] = androidInfo.device;
        deviceData['isPhysicalDevice'] = androidInfo.isPhysicalDevice;
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        deviceData['model'] = iosInfo.model;
        deviceData['systemName'] = iosInfo.systemName;
        deviceData['systemVersion'] = iosInfo.systemVersion;
        deviceData['localizedModel'] = iosInfo.localizedModel;
        deviceData['isPhysicalDevice'] = iosInfo.isPhysicalDevice;
      }

      // 최종 데이터 맵 구성
      final Map<String, dynamic> settingsMap = {
        'deviceInfo': deviceData,
        'appVersion': appVersion,
        'platform': Platform.isAndroid ? 'Android' : 'iOS',
        'lastUpdateTime': DateTime.now().millisecondsSinceEpoch,
      };

      // 서버에 저장
      return await setUserSetting(settingsMap);
    } catch (e) {
      log('[SettingApi.saveDeviceInfo] Exception: $e');
      return false;
    }
  }
}
