import 'dart:developer';
import 'package:graphql_flutter/graphql_flutter.dart';

import 'client.dart'; // client.dart

/// 통화 / 문자 로그 관련 API
class LogApi {
  // ==================== updateCallLog ====================
  static const String _updateCallLogMutation = r'''
    mutation updateCallLog($logs:[CallLogInput!]!) {
      updateCallLog(logs:$logs)
    }
  ''';

  /// 통화내역 업로드
  /// logs 예:
  ///  [
  ///    {"phoneNumber":"010-1234","time":"1696000123456","callType":"IN"},
  ///    ...
  ///  ]
  static Future<bool> updateCallLog(List<Map<String, dynamic>> logs) async {
    final client = GraphQLClientManager.client;
    final token = GraphQLClientManager.accessToken;
    if (token == null) throw Exception('로그인 필요');

    final opts = MutationOptions(
      document: gql(_updateCallLogMutation),
      variables: {'logs': logs},
    );

    final result = await client.mutate(opts);
    GraphQLClientManager.handleExceptions(result);

    final updated = result.data?['updateCallLog'] as bool? ?? false;
    if (updated) {
      log('통화로그 업로드 성공');
    } else {
      log('통화로그 업로드 실패');
    }
    return updated;
  }

  // ==================== updateSMSLog ====================
  static const String _updateSmsLogMutation = r'''
    mutation updateSMSLog($logs:[SMSLogInput!]!){
      updateSMSLog(logs:$logs)
    }
  ''';

  /// 문자내역 업로드
  /// logs 예:
  ///  [
  ///    {"phoneNumber":"010-5678","time":"1696000123456","content":"Hello","smsType":"OUT"},
  ///    ...
  ///  ]
  static Future<bool> updateSMSLog(List<Map<String, dynamic>> logs) async {
    final client = GraphQLClientManager.client;
    final token = GraphQLClientManager.accessToken;
    if (token == null) throw Exception('로그인 필요');

    final opts = MutationOptions(
      document: gql(_updateSmsLogMutation),
      variables: {'logs': logs},
    );

    final result = await client.mutate(opts);
    GraphQLClientManager.handleExceptions(result);

    final updated = result.data?['updateSMSLog'] as bool? ?? false;
    if (updated) {
      log('문자로그 업로드 성공');
    } else {
      log('문자로그 업로드 실패');
    }
    return updated;
  }
}
