import 'dart:developer';
import 'package:flutter/foundation.dart';
import 'package:get_storage/get_storage.dart';
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
          systemId
          loginId
          name
          phoneNumber
          type
          createdAt
          validUntil
        }
      }
    }
  ''';

  static Future<void> userLogin({
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
    // 저장 (기존)
    GraphQLClientManager.accessToken = token;

    // 새로 반환된 user
    final userData = data['user'];
    if (userData == null) {
      throw Exception('user 필드가 null임');
    }
    debugPrint('[[userLogin]] user=$userData');

    // GetStorage 에 유저정보 저장
    final box = GetStorage();
    box.write('userId', userData['id']);
    box.write('userName', userData['name']);
    box.write('userType', userData['type'].toString());
    box.write('loginStatus', true);
    box.write('userValidUntil', userData['validUntil'] ?? '');
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
    GraphQLClientManager.handleExceptions(result);

    final data = result.data?['userChangePassword'];
    if (data == null) {
      throw Exception('비밀번호 변경 응답이 null');
    }
    final success = data['success'] as bool? ?? false;
    return success;
  }

  // (추가) 로그아웃 시
  // => GraphQLClientManager.logout();
}
