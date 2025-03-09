// lib/graphql/search_api.dart
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:mobile/graphql/client.dart';
import 'package:mobile/models/phone_records_model.dart';

class SearchApi {
  static const _getPhoneNumberQuery = r'''
    query getPhoneNumber($phoneNumber: String!) {
      getPhoneNumber(phoneNumber: $phoneNumber) {
        phoneNumber
        type
        records {
          userName
          userType
          name
          memo
          type
          createdAt
        }
      }
    }
  ''';

  static Future<PhoneNumberModel?> getPhoneNumber(String phone) async {
    final client = GraphQLClientManager.client;

    final options = QueryOptions(
      document: gql(_getPhoneNumberQuery),
      variables: {'phoneNumber': phone},
      fetchPolicy: FetchPolicy.networkOnly,
    );

    final result = await client.query(options);
    GraphQLClientManager.handleExceptions(result);

    final data = result.data?['getPhoneNumber'];
    if (data == null) return null;

    return PhoneNumberModel.fromJson(data);
  }
}
