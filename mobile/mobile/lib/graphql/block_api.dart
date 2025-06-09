import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:mobile/graphql/client.dart';

class BlockApi {
  // 콜폭/ㅋㅍ 번호 목록 조회 쿼리 (서버의 getBlockNumbers)
  static const _queryGetBombCallBlockNumbers = r'''
    query getBlockNumbers($count: Int!) {
      getBlockNumbers(count: $count) {
        phoneNumber
        blockCount
      }
    }
  ''';

  // 사용자가 개인적으로 차단한 번호 목록 조회 쿼리 (서버의 getUserBlockNumbers)
  static const _queryGetUserBlockedNumbers = r'''
    query getUserBlockNumbers {
      getUserBlockNumbers
    }
  ''';

  /// 콜폭/ㅋㅍ 번호 목록 조회
  ///
  /// 특정 횟수(count) 이상 "콜폭" 또는 "ㅋㅍ"으로 마킹된 번호 목록을 가져옵니다.
  /// 서버의 getBlockNumbers API를 호출합니다.
  ///
  /// @param count 차단 기준이 되는 콜폭/ㅋㅍ 마킹 횟수
  /// @return phoneNumber와 blockCount를 포함한 맵 리스트
  static Future<List<Map<String, dynamic>>> getBombCallBlockNumbers(
    int count,
  ) async {
    final client = GraphQLClientManager.client;
    final token = GraphQLClientManager.accessToken;
    if (token == null) throw Exception('로그인 필요');

    final opts = QueryOptions(
      document: gql(_queryGetBombCallBlockNumbers),
      variables: {'count': count},
      fetchPolicy: FetchPolicy.networkOnly,
    );

    final result = await client.query(opts);
    GraphQLClientManager.handleExceptions(result);

    final data = result.data?['getBlockNumbers'] as List?;
    if (data == null) return [];

    return data.map((e) => e as Map<String, dynamic>).toList();
  }

  /// 사용자가 개인적으로 차단한 번호 목록 조회
  ///
  /// 현재 로그인된 사용자가 직접 차단한 번호 목록을 가져옵니다.
  /// 서버의 getUserBlockNumbers API를 호출합니다.
  ///
  /// @return 차단된 전화번호 문자열 리스트
  static Future<List<String>> getUserBlockedNumbers() async {
    final client = GraphQLClientManager.client;
    final token = GraphQLClientManager.accessToken;
    if (token == null) throw Exception('로그인 필요');

    final opts = QueryOptions(
      document: gql(_queryGetUserBlockedNumbers),
      fetchPolicy: FetchPolicy.networkOnly,
    );

    final result = await client.query(opts);
    GraphQLClientManager.handleExceptions(result);

    final List<dynamic> data = result.data?['getUserBlockNumbers'] ?? [];
    return data.map((number) => number.toString()).toList();
  }

  // 사용자 차단 번호 목록 업데이트 뮤테이션
  static const String _updateBlockedNumbersMutation = r'''
    mutation UpdateBlockedNumbers($numbers: [String!]!) {
      updateBlockedNumbers(numbers: $numbers)
    }
  ''';

  /// 사용자 차단 번호 목록 업데이트
  ///
  /// 현재 로그인된 사용자의 차단 번호 목록을 서버에 업데이트합니다.
  /// 서버의 updateBlockedNumbers API를 호출합니다.
  ///
  /// @param numbers 업데이트할 차단 번호 리스트
  /// @return 업데이트된 차단 번호 리스트
  static Future<List<String>> updateBlockedNumbers(List<String> numbers) async {
    final client = GraphQLClientManager.client;
    final token = GraphQLClientManager.accessToken;
    if (token == null) throw Exception('로그인 필요');

    final opts = MutationOptions(
      document: gql(_updateBlockedNumbersMutation),
      variables: {'numbers': numbers},
    );

    final result = await client.mutate(opts);
    GraphQLClientManager.handleExceptions(result);

    final List<dynamic> data = result.data?['updateBlockedNumbers'] ?? [];
    return data.map((number) => number.toString()).toList();
  }
}
