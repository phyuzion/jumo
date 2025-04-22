import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:mobile/graphql/client.dart';
import 'package:mobile/models/today_record.dart';

class TodayRecordApi {
  static const _getTodayRecordQuery = r'''
    query GetTodayRecord($phoneNumber: String!) {
      getTodayRecord(phoneNumber: $phoneNumber) {
        id
        phoneNumber
        userName
        userType
        interactionType
        createdAt
      }
    }
  ''';

  static Future<List<TodayRecord>> getTodayRecord(String phoneNumber) async {
    final client = GraphQLClientManager.client;

    final options = QueryOptions(
      document: gql(_getTodayRecordQuery),
      variables: {'phoneNumber': phoneNumber},
      fetchPolicy: FetchPolicy.networkOnly,
    );

    final result = await client.query(options);
    GraphQLClientManager.handleExceptions(result);

    final List<dynamic> records = result.data?['getTodayRecord'] ?? [];
    return records.map((json) => TodayRecord.fromJson(json)).toList();
  }
}
