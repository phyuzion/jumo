import 'dart:developer';
import 'package:graphql_flutter/graphql_flutter.dart';

import 'client.dart'; // client.dart

/// upsertPhoneRecords mutation
const String _upsertPhoneRecordsMutation = r'''
  mutation upsertPhoneRecords($records: [PhoneRecordInput!]!) {
    upsertPhoneRecords(records: $records)
  }
''';

class PhoneRecordsApi {
  static Future<bool> upsertPhoneRecords(
    List<Map<String, dynamic>> records,
  ) async {
    final client = GraphQLClientManager.client;
    final token = GraphQLClientManager.accessToken;
    if (token == null) throw Exception('로그인 필요');

    final opts = MutationOptions(
      document: gql(_upsertPhoneRecordsMutation),
      variables: {'records': records},
    );

    final result = await client.mutate(opts);

    GraphQLClientManager.handleExceptions(result);

    final updated = result.data?['upsertPhoneRecords'] as bool? ?? false;

    return updated;
  }
}
