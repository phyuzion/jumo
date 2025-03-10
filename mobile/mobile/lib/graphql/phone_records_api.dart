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

  // 신규 쿼리
  static const _queryGetMyRecords = r'''
    query getMyRecords {
      getMyRecords {
        phoneNumber
        name
        memo
        type
        createdAt
      }
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

  /// "내 기록" 전체 조회
  /// 반환 형식: List<Map<String, dynamic>>
  ///   각 item = { 'phoneNumber': ..., 'name':..., 'memo':..., 'type':..., 'createdAt':... }
  static Future<List<Map<String, dynamic>>> getMyRecords() async {
    final client = GraphQLClientManager.client;

    final opts = QueryOptions(document: gql(_queryGetMyRecords));

    final result = await client.query(opts);
    GraphQLClientManager.handleExceptions(result);

    // getMyRecords 가 배열 => List<dynamic>
    final data = result.data?['getMyRecords'] as List?;
    if (data == null) return [];

    // 각 element 는 Map<String, dynamic> 로 변환 가능
    final List<Map<String, dynamic>> list =
        data.map((e) => e as Map<String, dynamic>).toList();
    return list;
  }
}
