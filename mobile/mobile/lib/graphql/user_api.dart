import 'dart:developer';
// import 'package:hive_ce/hive.dart'; // <<< 제거
import 'package:graphql_flutter/graphql_flutter.dart';
// import 'package:mobile/repositories/auth_repository.dart'; // <<< 제거 (UserApi는 static 유지)

import 'client.dart';
import 'setting_api.dart'; // SettingApi 추가
import 'package:mobile/utils/constants.dart'; // APP_VERSION 상수 사용

/// 사용자 관련 API 모음
class UserApi {
  // <<< 생성자 및 멤버 변수 제거 >>>

  // ==================== 1) userLogin ====================
  static const String _userLoginMutation = r'''
    mutation userLogin($loginId: String!, $password: String!, $phoneNumber: String!) {
      userLogin(loginId: $loginId, password: $password, phoneNumber: $phoneNumber) {
        accessToken
        refreshToken
        user {
          id
          loginId
          name
          phoneNumber
          userType
          createdAt
          validUntil
          region
          grade
          # blockList 제거됨 (GraphQL 주석 # 사용)
        }
      }
    }
  ''';

  // <<< static 유지 >>>
  static Future<Map<String, dynamic>?> userLogin({
    required String loginId,
    required String password,
    required String phoneNumber,
  }) async {
    log('[UserApi.userLogin] loginId=$loginId, phone=$phoneNumber');
    final client = GraphQLClientManager.client;

    final options = MutationOptions(
      document: gql(_userLoginMutation),
      variables: {
        'loginId': loginId,
        'password': password,
        'phoneNumber': phoneNumber,
      },
    );

    final QueryResult result = await client.mutate(options);

    // <<< 예외 발생 여부 먼저 확인 >>>
    if (result.hasException) {
      log(
        '[UserApi.userLogin] Mutation failed with exception: ${result.exception.toString()}',
      );
      // GraphQL 에러 로깅 및 처리는 handleExceptions에 맡길 수도 있지만,
      // 여기서는 예외를 바로 던져서 호출부(login_screen)에서 처리하도록 함
      throw result.exception!; // OperationException을 그대로 던짐
    }

    // <<< 예외가 없을 때만 데이터 확인 >>>
    final data = result.data?['userLogin'];
    if (data == null) {
      // 서버가 오류 없이 null 데이터를 반환한 경우 (비정상 케이스)
      throw Exception('로그인 응답 형식이 올바르지 않습니다.'); // 메시지 명확화
    }

    // --- 성공 로직 (토큰 설정 및 데이터 반환) ---
    final token = data['accessToken'] as String?;
    if (token == null) {
      throw Exception('토큰 정보가 없습니다.');
    }
    // <<< setAccessToken 호출로 수정된 것 유지 >>>
    await GraphQLClientManager.setAccessToken(token);

    final userData = data['user'] as Map<String, dynamic>?;
    if (userData == null) {
      throw Exception('사용자 정보가 없습니다.');
    }
    log('[[userLogin]] user=$userData');

    // <<< Hive 저장 로직은 여기서 제거됨 (login_screen에서 처리) >>>

    // 로그인 성공 시 디바이스 정보 저장 (비동기로 실행하고 결과를 기다리지 않음)
    try {
      log('[UserApi.userLogin] Saving device info after login');
      SettingApi.saveDeviceInfo(appVersion: APP_VERSION)
          .then((success) {
            log('[UserApi.userLogin] Device info saved: $success');
          })
          .catchError((e) {
            log('[UserApi.userLogin] Error saving device info: $e');
          });
    } catch (e) {
      log('[UserApi.userLogin] Error initiating device info save: $e');
    }

    // API 결과 데이터만 반환
    return data;
  }

  // ==================== 2) userChangePassword ====================
  static const String _userChangePwMutation = r'''
    mutation userChangePassword($oldPassword:String!, $newPassword:String!) {
      userChangePassword(oldPassword:$oldPassword, newPassword:$newPassword) {
        success
        user {
          id
          name
          phoneNumber
        }
      }
    }
  ''';

  /// 비밀번호 변경
  // <<< static 유지 >>>
  static Future<bool> userChangePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    final client = GraphQLClientManager.client;
    final token = GraphQLClientManager.accessToken;
    if (token == null) throw Exception('로그인 필요');

    final opts = MutationOptions(
      document: gql(_userChangePwMutation),
      variables: {'oldPassword': oldPassword, 'newPassword': newPassword},
    );

    final result = await client.mutate(opts);
    await GraphQLClientManager.handleExceptions(result);

    final data = result.data?['userChangePassword'];
    if (data == null) {
      throw Exception('비밀번호 변경 응답이 null');
    }
    final success = data['success'] as bool? ?? false;

    // <<< 성공 시 비밀번호 업데이트 로직 제거 >>>

    return success;
  }

  // (추가) 로그아웃 시
  // => GraphQLClientManager.logout();
}
