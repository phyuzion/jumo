// lib/graphql/notification_api.dart
import 'dart:developer';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:mobile/graphql/client.dart';

class NotificationApi {
  static const _queryGetNotifications = r'''
    query {
      getNotifications {
        id
        title
        message
        validUntil
        createdAt
        targetUserId
      }
    }
  ''';

  static Future<List<Map<String, dynamic>>> getNotifications() async {
    final client = GraphQLClientManager.client;
    final opts = QueryOptions(document: gql(_queryGetNotifications));

    final result = await client.query(opts);
    GraphQLClientManager.handleExceptions(result);

    final data = result.data?['getNotifications'] as List?;
    if (data == null) return [];

    final list = data.map((e) => e as Map<String, dynamic>).toList();
    log('[NotificationApi] getNotifications => count=${list.length}');
    return list;
  }
}
