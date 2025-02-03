// lib/graphql/mutations.dart
import 'package:graphql_flutter/graphql_flutter.dart';

final String CLIENT_LOGIN = r'''
mutation clientLogin($userId: String!, $phone: String!) {
  clientLogin(userId: $userId, phone: $phone) {
    success
    user {
      userId
      phone
      name
      memo
      validUntil
      createdAt
    }
  }
}
''';
