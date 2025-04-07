// lib/graphql/client.dart
import 'dart:developer';
import 'dart:io'; // <-- HttpClient
import 'package:hive_ce/hive.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:http/io_client.dart'; // <-- IOClient
import 'package:mobile/controllers/navigation_controller.dart';
import 'package:mobile/graphql/user_api.dart';
import 'package:mobile/models/blocked_history.dart';

/// 공통 Endpoint
const String kGraphQLEndpoint = 'https://jumo-vs8e.onrender.com/graphql';

/// GraphQL 통신 공통 로직
class GraphQLClientManager {
  // GetStorage 인스턴스 제거
  static Box get _authBox => Hive.box('auth');

  /// AccessToken Getter / Setter
  static String? get accessToken => _authBox.get('accessToken') as String?;
  static set accessToken(String? token) {
    if (token == null) {
      _authBox.delete('accessToken');
    } else {
      log('[GraphQL] Saving accessToken to Hive...');
      _authBox.put('accessToken', token);
    }
  }

  // ===============================
  // 1) 자동로그인 함수 (id/pw 재로그인)
  static Future<void> tryAutoLogin() async {
    final savedId = _authBox.get('savedLoginId') as String?;
    final savedPw = _authBox.get('savedPassword') as String?;
    final myNumber = _authBox.get('myNumber') as String?;

    if (savedId == null ||
        savedId.isEmpty ||
        savedPw == null ||
        savedPw.isEmpty ||
        myNumber == null ||
        myNumber.isEmpty) {
      log('[GraphQL] No saved credentials found for auto-login.');
      await logout();
    } else {
      try {
        final loginResult = await UserApi.userLogin(
          loginId: savedId,
          password: savedPw,
          phoneNumber: myNumber,
        );
        log(
          '[GraphQL] tryAutoLogin: Re-login success with $savedId, $myNumber',
        );
      } catch (e) {
        log('[GraphQL] tryAutoLogin failed: $e');
        await logout();
      }
    }
  }

  /// 로그아웃 (Hive 데이터 삭제)
  static Future<void> logout() async {
    log('[GraphQL] Logging out and clearing user data...');
    // 필요한 Box들을 가져와서 clear 호출 (타입 지정 없이)

    try {
      await Hive.box('auth').clear();
      await Hive.box('notifications').clear();
      await Hive.box('last_sync_state').clear();
      await Hive.box<BlockedHistory>('blocked_history').clear();
      await Hive.box('call_logs').clear();
      await Hive.box('sms_logs').clear();
      await Hive.box('display_noti_ids').clear();
      await Hive.box('blocked_numbers').clear();

      log('[GraphQL] Cleared user-specific Hive boxes.');
    } catch (e) {
      log('[GraphQL] Error clearing Hive boxes during logout: $e');
    }

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

  /// 자동 로그인 정보 저장 함수 추가
  static Future<void> saveLoginCredentials(
    String id,
    String pw,
    String myNumber,
  ) async {
    await _authBox.put('savedLoginId', id);
    await _authBox.put('savedPassword', pw);
    await _authBox.put('myNumber', myNumber);
    log('[GraphQL] Saved login credentials to Hive.');
  }

  /// 헬퍼: GraphQL Exception 핸들링
  ///  - 서버 GraphQLError가 있을 경우, 메시지 추출
  static Future<void> handleExceptions(QueryResult result) async {
    // result.data가 null이면 그냥 리턴 (예외 아님)
    if (result.data == null) {
      return;
    }

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
