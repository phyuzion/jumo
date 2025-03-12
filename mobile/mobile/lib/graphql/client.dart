import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:mobile/controllers/navigation_controller.dart';

// 전역 NavigatorKey (MaterialApp에서 navigatorKey: appNavKey)
final GlobalKey<NavigatorState> appNavKey = GlobalKey<NavigatorState>();

// ===============================
// 1) 자동로그인 함수 (id/pw 재로그인)
Future<bool> tryAutoLogin() async {
  final box = GetStorage();
  final savedId = box.read<String>('savedLoginId');
  final savedPw = box.read<String>('savedPassword');
  final myNumber = box.read<String>('myNumber');
  if (savedId == null || savedPw == null || myNumber == null) {
    return false;
  }

  try {
    // 예: UserApi.userLogin(...)
    // await UserApi.userLogin(loginId: savedId, password: savedPw, phoneNumber: myNumber);
    log('[tryAutoLogin] re-login success with $savedId');
    return true;
  } catch (e) {
    log('[tryAutoLogin] failed: $e');
    return false;
  }
}

// ===============================
// 2) GraphQLClientManager
const String kGraphQLEndpoint = 'https://jumo-vs8e.onrender.com/graphql';

class GraphQLClientManager {
  static final GetStorage _box = GetStorage();

  static String? get accessToken => _box.read<String>('accessToken');
  static set accessToken(String? token) {
    if (token == null) {
      _box.remove('accessToken');
    } else {
      log('box write access token : $token');
      _box.write('accessToken', token);
    }
  }

  static void logout() {
    accessToken = null;
    _box.erase();

    NavigationController.goToDecider();
  }

  static GraphQLClient get client {
    final httpLink = HttpLink(kGraphQLEndpoint);

    final authLink = AuthLink(
      getToken: () {
        final t = accessToken;
        return t != null ? 'Bearer $t' : null;
      },
    );

    final link = authLink.concat(httpLink);

    return GraphQLClient(cache: GraphQLCache(), link: link);
  }

  /// GraphQL 예외 핸들
  /// - "로그인이 필요합니다" → 자동로그인 → 실패 시 /login
  static Future<void> handleExceptions(QueryResult result) async {
    if (!result.hasException) return;

    if (result.exception?.graphqlErrors.isNotEmpty == true) {
      final msg = result.exception!.graphqlErrors.first.message;
      if (msg.contains('로그인이 필요합니다')) {
        final ok = await tryAutoLogin();
        if (!ok) {
          logout();
        }
      }
      throw Exception(msg);
    } else if (result.exception?.linkException != null) {
      final linkErr = result.exception!.linkException.toString();
      throw Exception('GraphQL LinkException: $linkErr');
    } else {
      throw Exception('GraphQL unknown exception');
    }
  }
}
