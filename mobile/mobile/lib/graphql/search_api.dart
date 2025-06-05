// lib/graphql/search_api.dart
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:mobile/graphql/client.dart';
import 'package:mobile/models/phone_number_model.dart';
import 'dart:developer';

class SearchApi {
  static const _getPhoneNumberQuery = r'''
    query getPhoneNumber($phoneNumber: String!, $isRequested: Boolean) {
      getPhoneNumber(phoneNumber: $phoneNumber, isRequested: $isRequested) {
        id
        phoneNumber
        type
        blockCount
        records {
          userName
          userType
          name
          memo
          type
          createdAt
          phoneNumber
        }
        todayRecords {
          id
          phoneNumber
          userName
          userType
          interactionType
          createdAt
        }
      }
    }
  ''';

  static Future<PhoneNumberModel?> getPhoneNumber(
    String phone, {
    bool isRequested = false,
  }) async {
    final client = GraphQLClientManager.client;

    await client.resetStore(refetchQueries: false);
    log('[SearchApi] GraphQL cache reset.');

    final options = QueryOptions(
      document: gql(_getPhoneNumberQuery),
      variables: {'phoneNumber': phone, 'isRequested': isRequested},
      fetchPolicy: FetchPolicy.networkOnly,
    );

    final result = await client.query(options);

    if (result.hasException) {
      final exception = result.exception!;
      if (exception is OperationException &&
          exception.graphqlErrors.isNotEmpty) {
        for (final error in exception.graphqlErrors) {
          // FORBIDDEN 코드는 예시이며, 실제 서버 응답에 따라 조절 필요
          if (error.extensions?['code'] == 'FORBIDDEN' &&
              error.message.contains('오늘의 검색 제한')) {
            log(
              '[SearchApi] Throwing specific error for search limit: ${error.message}',
            );
            throw Exception(error.message);
          }
        }
      }
      GraphQLClientManager.handleExceptions(result);
    }

    final data = result.data?['getPhoneNumber'];
    log('[SearchApi] Raw data received from server for $phone: $data');

    if (data == null) {
      log('[SearchApi] No data received from server for $phone.');
      return null;
    }

    try {
      log('[SearchApi] Attempting to parse data into PhoneNumberModel...');
      final model = PhoneNumberModel.fromJson(data as Map<String, dynamic>);
      log('[SearchApi] Parsed model: ${model.toJson()}');
      return model;
    } catch (e, st) {
      log('[SearchApi] Error parsing PhoneNumberModel: $e\n$st');
      return null;
    }
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
