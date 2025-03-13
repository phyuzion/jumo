// version_api.dart
import 'dart:developer';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'client.dart'; // GraphQLClientManager가 정의된 파일

class VersionApi {
  static const String _checkApkVersionQuery = r'''
    query {
      checkAPKVersion
    }
  ''';

  /// 서버에서 APK 버전 문자열을 가져옴
  static Future<String> getApkVersion() async {
    final client = GraphQLClientManager.client;
    // 토큰 필요 없으면 생략
    // final token = GraphQLClientManager.accessToken;
    // if(token==null) throw Exception('로그인 필요');

    final options = QueryOptions(
      document: gql(_checkApkVersionQuery),
      fetchPolicy: FetchPolicy.networkOnly,
    );

    final result = await client.query(options);

    // handleExceptions는 사용자별 커스텀 로직일 수도
    GraphQLClientManager.handleExceptions(result);

    if (result.data == null) {
      throw Exception('checkAPKVersion 응답이 null.');
    }

    final serverVersion = result.data?['checkAPKVersion'] as String? ?? '';
    log('[VersionApi.getApkVersion] serverVersion=$serverVersion');
    return serverVersion;
  }
}
