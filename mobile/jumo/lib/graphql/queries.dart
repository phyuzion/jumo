import 'package:graphql_flutter/graphql_flutter.dart';

final String GET_CALL_LOGS_FOR_USER = r'''
query getCallLogsForUser($userId: String!, $phone: String!, $start: Int!, $end: Int!) {
  getCallLogsForUser(userId: $userId, phone: $phone, start: $start, end: $end) {
    _id
    timestamp
    score
    memo
    userId {
      name
      phone
    }
    customerId {
      phone
      averageScore
    }
  }
}
''';

final String GET_CUSTOMER_BY_PHONE = r'''
query getCustomerByPhone($userId: String, $phone: String, $searchPhone: String!) {
  getCustomerByPhone(userId: $userId, phone: $phone, searchPhone: $searchPhone) {
    customer {
      _id
      phone
      totalCalls
      averageScore
    }
    callLogs {
      _id
      timestamp
      score
      memo
      userId {
        userId
        phone
      }
    }
  }
}
''';
