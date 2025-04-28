import 'dart:developer';
// import 'package:hive_ce/hive.dart'; // <<< 제거
import 'package:graphql_flutter/graphql_flutter.dart';
// import 'package:mobile/repositories/auth_repository.dart'; // <<< 제거 (UserApi는 static 유지)

import 'client.dart';

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

    final result = await client.mutate(options);
    GraphQLClientManager.handleExceptions(result);

    final data = result.data?['userLogin'];
    if (data == null) {
      throw Exception('로그인 응답이 null');
    }

    final token = data['accessToken'] as String?;
    if (token == null) {
      throw Exception('accessToken이 null');
    }
    await GraphQLClientManager.setAccessToken(token);

    final userData = data['user'] as Map<String, dynamic>?;
    if (userData == null) {
      throw Exception('user 필드가 null임');
    }
    log('[[userLogin]] user=$userData');

    // <<< Hive 저장 로직 모두 제거 >>>
    // await _authRepository.setToken(token); // 제거
    // await _authRepository.setUserId(userData['id'] ?? ''); // 제거
    // await _authRepository.setUserName(userData['name'] ?? ''); // 제거
    // await _authRepository.setUserType(userData['userType'] ?? ''); // 제거
    // await _authRepository.setLoginStatus(true); // 제거
    // await _authRepository.setUserValidUntil(userData['validUntil'] ?? ''); // 제거
    // await _authRepository.setUserRegion(userData['region'] ?? ''); // 제거
    // await _authRepository.setUserGrade(userData['grade'] ?? ''); // 제거
    // if (userData.containsKey('loginId')) { ... } // 제거

    // <<< GraphQLClientManager.saveLoginCredentials 호출 제거 >>>

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
