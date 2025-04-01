// lib/graphql/client.dart
import 'dart:developer';
import 'dart:io'; // <-- HttpClient
import 'package:get_storage/get_storage.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:http/io_client.dart'; // <-- IOClient
import 'package:mobile/controllers/navigation_controller.dart';
import 'package:mobile/graphql/user_api.dart';
import 'package:mobile/services/native_methods.dart';
import 'package:mobile/utils/constants.dart';

/// 공통 Endpoint
const String kGraphQLEndpoint = 'https://jumo-vs8e.onrender.com/graphql';

/// GraphQL 통신 공통 로직
class GraphQLClientManager {
  // GetStorage 인스턴스
  static final GetStorage _box = GetStorage();

  /// AccessToken Getter / Setter
  static String? get accessToken => _box.read<String>('accessToken');
  static set accessToken(String? token) {
    if (token == null) {
      _box.remove('accessToken');
    } else {
      log('box write access token : $token');
      _box.write('accessToken', token);
    }
  }

  // ===============================
  // 1) 자동로그인 함수 (id/pw 재로그인)
  static Future<void> tryAutoLogin() async {
    final box = GetStorage();
    final savedId = box.read<String>('savedLoginId');
    final savedPw = box.read<String>('savedPassword');
    final myNumber = box.read<String>('myNumber');

    if ((savedId == null || savedId.isEmpty) ||
        (savedPw == null || savedPw.isEmpty) ||
        (myNumber == null || myNumber.isEmpty)) {
      logout();
    } else {
      try {
        await UserApi.userLogin(
          loginId: savedId,
          password: savedPw,
          phoneNumber: myNumber,
        );
        log('[tryAutoLogin] re-login success with $savedId , $myNumber');
      } catch (e) {
        log('[tryAutoLogin] failed: $e');
        logout();
      }
    }
  }

  /// 로그아웃 → 토큰 제거 후 DeciderScreen 으로 이동
  static void logout() {
    accessToken = null;
    _box.erase(); // 모든 저장 데이터 초기화
    NavigationController.goToDecider();
  }

  /// 내부 GraphQLClient 생성
  /// - 여기에서 HttpClient + IOClient로 타임아웃을 늘려서 TimeoutException을 완화
  static GraphQLClient get client {
    // 1) HttpClient 구성: 연결/유휴 타임아웃을 원하는 만큼 늘린다 (예: 30초)
    final httpClient =
        HttpClient()
          ..connectionTimeout = const Duration(seconds: 30)
          ..idleTimeout = const Duration(seconds: 30);

    // 2) IOClient 생성 -> HttpLink 에 주입
    final ioClient = IOClient(httpClient);

    final httpLink = HttpLink(
      kGraphQLEndpoint,
      httpClient: ioClient, // 중요!
    );

    final authLink = AuthLink(
      // 토큰 있으면 Authorization: Bearer xxx
      getToken: () {
        final token = accessToken;
        if (token == null) return null;
        return 'Bearer $token';
      },
    );

    final link = authLink.concat(httpLink);

    return GraphQLClient(cache: GraphQLCache(), link: link);
  }

  /// 헬퍼: GraphQL Exception 핸들링
  ///  - 서버 GraphQLError가 있을 경우, 메시지 추출
  static void handleExceptions(QueryResult result) {
    if (result.hasException) {
      // 타임아웃 에러는 무시
      if (result.exception?.linkException.toString().contains(
            'TimeoutException',
          ) ==
          true) {
        return;
      }

      if (result.exception?.graphqlErrors.isNotEmpty == true) {
        final msg = result.exception!.graphqlErrors.first.message;
        if (msg.contains('로그인이 필요합니다')) {
          log('new login start');
          tryAutoLogin();
        }
        throw Exception(msg);
      } else if (result.exception?.linkException != null) {
        // 네트워크/서버접속 에러, Timeout 등
        final linkErr = result.exception!.linkException.toString();
        throw Exception('GraphQL LinkException: $linkErr');
      } else {
        throw Exception('GraphQL unknown exception');
      }
    }
  }
}
