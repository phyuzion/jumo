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
        isRegisteredUser
        registeredUserInfo {
          userName
          userRegion
          userType
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
    // GraphQLClientManager.handleExceptions(result); // <<< 기존 호출은 주석 처리 또는 수정
    // 직접 예외를 확인하거나, 수정된 handleExceptions를 호출합니다.
    // 아래는 직접 확인하는 예시이며, 실제로는 GraphQLClientManager의 수정된 함수를 호출하는 것이 좋습니다.

    if (result.hasException) {
      final exception = result.exception!;
      if (exception is OperationException &&
          exception.graphqlErrors.isNotEmpty) {
        for (final error in exception.graphqlErrors) {
          // FORBIDDEN 코드는 예시이며, 실제 서버 응답에 따라 조절 필요
          if (error.extensions?['code'] == 'FORBIDDEN' &&
              error.message.contains('오늘의 검색 제한')) {
            // 이 특정 에러를 호출부에서 잡을 수 있도록 커스텀 예외를 발생시킵니다.
            // SearchLimitExceededException은 별도로 정의해야 합니다.
            // 여기서는 간단히 OperationException을 다시 throw하거나, 특정 메시지를 가진 일반 Exception을 throw 할 수 있습니다.
            // 가장 좋은 방법은 SearchLimitExceededException 같은 커스텀 예외를 정의하고 사용하는 것입니다.
            // 지금은 간단히 메시지를 포함한 일반 Exception을 발생시키겠습니다.
            // 나중에 GraphQLClientManager에 SearchLimitExceededException을 정의하고 여기서 사용하세요.
            log(
              '[SearchApi] Throwing specific error for search limit: ${error.message}',
            );
            throw Exception(
              error.message,
            ); // SearchLimitExceededException(error.message);
          }
        }
      }
      // 그 외 다른 GraphQL 예외나 네트워크 예외는 그대로 전파하거나 기본 핸들링
      GraphQLClientManager.handleExceptions(result); // 로그 등 기타 처리
      // 또는 여기서 그냥 rethrow result.exception; 할 수도 있습니다.
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
