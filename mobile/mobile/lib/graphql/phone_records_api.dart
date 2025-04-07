// lib/graphql/phone_records_api.dart
import 'dart:developer';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:mobile/graphql/client.dart';
// ↑ GraphQLClientManager (accessToken, handleExceptions 등) 이 있다고 가정

class PhoneRecordsApi {
  static const _mutationUpsert = r'''
    mutation upsertPhoneRecords($records: [PhoneRecordInput!]!) {
      upsertPhoneRecords(records: $records)
    }
  ''';

  // 신규 쿼리: 특정 전화번호 정보 조회
  static const _queryGetPhoneRecord = r'''
    query getPhoneRecord($phoneNumber: String!) {
      getPhoneRecord(phoneNumber: $phoneNumber) {
        phoneNumber
        name
        memo
        type
        createdAt
      }
    }
  ''';

  /// 단일 또는 여러 phoneRecords 업서트 (백그라운드 업데이트 및 저장 시 사용)
  /// records 예: [{phoneNumber, name, memo?, type?, createdAt(UTC)}, ...]
  static Future<void> upsertPhoneRecords(
    List<Map<String, dynamic>> records,
  ) async {
    if (records.isEmpty) {
      log('[PhoneRecordsApi] No records to upsert => skip.');
      return;
    }
    final client = GraphQLClientManager.client;

    log('[PhoneRecordsApi] Upserting ${records.length} records...');
    final opts = MutationOptions(
      document: gql(_mutationUpsert),
      variables: {'records': records},
    );

    final result = await client.mutate(opts);
    GraphQLClientManager.handleExceptions(result); // 실패 시 Exception 발생

    final updated = result.data?['upsertPhoneRecords'] as bool? ?? false;
    if (updated) {
      log(
        '[PhoneRecordsApi] upsertPhoneRecords success, count=${records.length}',
      );
    } else {
      // 서버에서 false를 반환하는 경우는 드물지만 로깅
      log(
        '[PhoneRecordsApi] upsertPhoneRecords returned false (data: ${result.data})',
      );
    }
  }

  /// 전화번호로 "내 기록" (타입, 메모 등) 조회
  /// 반환 형식: Map<String, dynamic>? (없으면 null)
  ///   Map = { 'phoneNumber': ..., 'name':..., 'memo':..., 'type':..., 'createdAt':... }
  static Future<Map<String, dynamic>?> getPhoneRecord(
    String phoneNumber,
  ) async {
    final client = GraphQLClientManager.client;

    final opts = QueryOptions(
      document: gql(_queryGetPhoneRecord),
      variables: {'phoneNumber': phoneNumber},
      // 필요 시 fetchPolicy 설정 (예: network-only)
      fetchPolicy: FetchPolicy.networkOnly,
    );

    final result = await client.query(opts);
    GraphQLClientManager.handleExceptions(result); // 실패 시 Exception 발생

    // getPhoneRecord는 단일 객체 또는 null 반환
    final data = result.data?['getPhoneRecord'] as Map<String, dynamic>?;
    return data;
  }
}
