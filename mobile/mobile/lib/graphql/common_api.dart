import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:mobile/graphql/client.dart';

class CommonApi {
  static const _queryGetRegions = r'''
    query getRegions {
      getRegions {
        name
      }
    }
  ''';

  static Future<List<Map<String, dynamic>>> getRegions() async {
    final client = GraphQLClientManager.client;
    final token = GraphQLClientManager.accessToken;
    if (token == null) throw Exception('로그인 필요');

    final opts = QueryOptions(
      document: gql(_queryGetRegions),
      fetchPolicy: FetchPolicy.networkOnly,
    );

    final result = await client.query(opts);
    GraphQLClientManager.handleExceptions(result);

    final data = result.data?['getRegions'] as List?;
    if (data == null) return [];

    return data.map((e) => e as Map<String, dynamic>).toList();
  }
}
