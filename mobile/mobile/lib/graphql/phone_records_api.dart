// lib/graphql/phone_records_api.dart
import 'dart:developer';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:mobile/graphql/client.dart';
// ↑ GraphQLClientManager (accessToken, handleExceptions 등) 이 있다고 가정

class PhoneRecordsApi {
  static const _mutation = r'''
    mutation upsertPhoneRecords($records: [PhoneRecordInput!]!) {
      upsertPhoneRecords(records: $records)
    }
  ''';

  /// 여러 phoneRecords 업서트
  /// records 예: [{phoneNumber,name,memo,type,createdAt}, ...]
  static Future<void> upsertPhoneRecords(
    List<Map<String, dynamic>> records,
  ) async {
    if (records.isEmpty) {
      log('[PhoneRecordsApi] No records => skip.');
      return;
    }
    final client = GraphQLClientManager.client;

    log('upload start');
    final opts = MutationOptions(
      document: gql(_mutation),
      variables: {'records': records},
    );

    final result = await client.mutate(opts);
    GraphQLClientManager.handleExceptions(result);

    final updated = result.data?['upsertPhoneRecords'] as bool? ?? false;
    if (updated) {
      log(
        '[PhoneRecordsApi] upsertPhoneRecords success, count=${records.length}',
      );
    } else {
      log('[PhoneRecordsApi] upsertPhoneRecords -> false');
    }
  }
}
