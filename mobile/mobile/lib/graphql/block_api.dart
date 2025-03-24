import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:mobile/graphql/client.dart';

class BlockApi {
  static const _queryGetBlockNumbers = r'''
    query getBlockNumbers($count: Int!) {
      getBlockNumbers(count: $count) {
        phoneNumber
        blockCount
      }
    }
  ''';

  static const _queryGetBlockedNumbers = r'''
    query getUserBlockNumbers {
      getUserBlockNumbers
    }
  ''';

  static Future<List<Map<String, dynamic>>> getBlockNumbers(int count) async {
    final client = GraphQLClientManager.client;
    final token = GraphQLClientManager.accessToken;
    if (token == null) throw Exception('로그인 필요');

    final opts = QueryOptions(
      document: gql(_queryGetBlockNumbers),
      variables: {'count': count},
      fetchPolicy: FetchPolicy.networkOnly,
    );

    final result = await client.query(opts);
    GraphQLClientManager.handleExceptions(result);

    final data = result.data?['getBlockNumbers'] as List?;
    if (data == null) return [];

    return data.map((e) => e as Map<String, dynamic>).toList();
  }

  static Future<List<String>> getBlockedNumbers() async {
    final client = GraphQLClientManager.client;
    final token = GraphQLClientManager.accessToken;
    if (token == null) throw Exception('로그인 필요');

    final opts = QueryOptions(
      document: gql(_queryGetBlockedNumbers),
      fetchPolicy: FetchPolicy.networkOnly,
    );

    final result = await client.query(opts);
    GraphQLClientManager.handleExceptions(result);

    final List<dynamic> data = result.data?['getUserBlockNumbers'] ?? [];
    return data.map((number) => number.toString()).toList();
  }

  static const String _updateBlockedNumbersMutation = r'''
    mutation UpdateBlockedNumbers($numbers: [String!]!) {
      updateBlockedNumbers(numbers: $numbers)
    }
  ''';

  /// 차단된 전화번호 목록 업데이트
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
