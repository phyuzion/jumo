import 'dart:developer';
// import 'package:get_storage/get_storage.dart'; // 제거
import 'package:hive_ce/hive.dart'; // Hive 추가
import 'package:graphql_flutter/graphql_flutter.dart';

import 'client.dart'; // 위에서 만든 client.dart

/// 사용자 관련 API 모음
class UserApi {
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
    // accessToken 저장 (GraphQLClientManager 내부에서 Hive 사용)
    GraphQLClientManager.accessToken = token;

    final userData = data['user'] as Map<String, dynamic>?; // 타입 명시
    if (userData == null) {
      throw Exception('user 필드가 null임');
    }
    log('[[userLogin]] user=$userData');

    // Hive 'auth' Box 에 유저정보 저장
    final authBox = Hive.box('auth');
    await authBox.put('userId', userData['id']);
    await authBox.put('userName', userData['name']);
    await authBox.put('userType', userData['userType']);
    await authBox.put('loginStatus', true);
    await authBox.put('userValidUntil', userData['validUntil'] ?? '');
    await authBox.put('userRegion', userData['region'] ?? '');
    await authBox.put('userGrade', userData['grade'] ?? '');
    // 자동 로그인을 위해 ID/PW/번호 저장 (GraphQLClientManager 함수 사용)
    await GraphQLClientManager.saveLoginCredentials(
      loginId,
      password,
      phoneNumber,
    );

    // 차단 목록 저장 부분은 이미 제거됨

    return data; // 결과 데이터 반환 (필요 시 사용)
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
    // handleExceptions 호출 (Future 반환하므로 await 추가)
    await GraphQLClientManager.handleExceptions(result);

    final data = result.data?['userChangePassword'];
    if (data == null) {
      throw Exception('비밀번호 변경 응답이 null');
    }
    final success = data['success'] as bool? ?? false;
    // 성공 시 저장된 비밀번호 업데이트 (선택적)
    if (success) {
      final authBox = Hive.box('auth');
      await authBox.put('savedPassword', newPassword);
    }
    return success;
  }

  // (추가) 로그아웃 시
  // => GraphQLClientManager.logout();
}
