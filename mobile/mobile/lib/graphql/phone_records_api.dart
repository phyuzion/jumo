// lib/graphql/phone_records_api.dart
import 'dart:developer';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:mobile/graphql/client.dart'; // GraphQLClientManager

/// upsertPhoneRecords Mutation
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

    final MutationOptions opts = MutationOptions(
      document: gql(_upsertPhoneRecordsMutation),
      variables: {'records': records},
    );

    final result = await client.mutate(opts);
    GraphQLClientManager.handleExceptions(result);

    final updated = result.data?['upsertPhoneRecords'] as bool? ?? false;

    return updated;
  }
}
