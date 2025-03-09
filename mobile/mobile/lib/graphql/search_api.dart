// lib/graphql/search_api.dart
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:mobile/graphql/client.dart';
import 'package:mobile/models/phone_number_model.dart';

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

  /// ====== 새로 추가: getPhoneNumbersByType ======
  static const _getPhoneNumbersByTypeQuery = r'''
    query getPhoneNumbersByType($type: Int!) {
      getPhoneNumbersByType(type: $type) {
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

  /// 위험번호(type=99) 등 특정 분류만 검색
  static Future<List<PhoneNumberModel>> getPhoneNumbersByType(int type) async {
    final client = GraphQLClientManager.client;

    final options = QueryOptions(
      document: gql(_getPhoneNumbersByTypeQuery),
      variables: {'type': type},
      fetchPolicy: FetchPolicy.networkOnly,
    );

    final result = await client.query(options);
    GraphQLClientManager.handleExceptions(result);

    final listData =
        result.data?['getPhoneNumbersByType'] as List<dynamic>? ?? [];
    final List<PhoneNumberModel> list =
        listData
            .map(
              (json) => PhoneNumberModel.fromJson(json as Map<String, dynamic>),
            )
            .toList();
    return list;
  }
}
