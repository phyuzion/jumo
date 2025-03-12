import 'dart:developer';
import 'package:get_storage/get_storage.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

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

  /// 로그아웃 → 토큰 제거
  static void logout() {
    accessToken = null;
    // refreshToken 도 관리하려면 비슷하게 제거
  }

  /// 내부 GraphQLClient 생성
  static GraphQLClient get client {
    final httpLink = HttpLink(kGraphQLEndpoint);

    final authLink = AuthLink(
      // 토큰 있으면 Authorization: Bearer xxx
      getToken: () {
        if (accessToken == null) return null;
        return 'Bearer $accessToken';
      },
    );

    final link = authLink.concat(httpLink);

    return GraphQLClient(cache: GraphQLCache(), link: link);
  }

  /// 헬퍼: GraphQL Exception 핸들링
  ///  - 서버 GraphQLError가 있을 경우, 메시지 추출
  static void handleExceptions(QueryResult result) {
    if (result.hasException) {
      if (result.exception?.graphqlErrors.isNotEmpty == true) {
        final msg = result.exception!.graphqlErrors.first.message;
        throw Exception(msg);
      } else if (result.exception?.linkException != null) {
        // 네트워크/서버접속 에러 등
        final linkErr = result.exception!.linkException.toString();
        throw Exception('GraphQL LinkException: $linkErr');
      } else {
        throw Exception('GraphQL unknown exception');
      }
    }
  }
}
