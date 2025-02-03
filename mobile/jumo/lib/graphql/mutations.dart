// lib/graphql/mutations.dart

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

final String CREATE_CALL_LOG = r'''
mutation createCallLog($userId: String!, $phone: String!, $customerPhone: String!, $score: Int, $memo: String) {
  createCallLog(userId: $userId, phone: $phone, customerPhone: $customerPhone, score: $score, memo: $memo) {
    callLog {
      _id
      timestamp
      score
      memo
      userId {
        userId
        phone
      }
      customerId {
        phone
        averageScore
      }
    }
    customer {
      _id
      phone
      totalCalls
      averageScore
    }
  }
}
''';

final String UPDATE_CALL_LOG = r'''
mutation updateCallLog($logId: ID!, $userId: String!, $phone: String!, $score: Int, $memo: String) {
  updateCallLog(logId: $logId, userId: $userId, phone: $phone, score: $score, memo: $memo) {
    _id
    timestamp
    score
    memo
    userId {
      userId
      phone
    }
    customerId {
      phone
      averageScore
    }
  }
}
''';
