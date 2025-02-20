import { gql } from '@apollo/client';

export const GET_SUMMARY = gql`
  query {
    getSummary {
      callLogsCount
      usersCount
      customersCount
    }
  }
`;


export const GET_USER_LIST = gql`
    query getUserList($start: Int!, $end: Int!) {
        getUserList(start: $start, end: $end) {
            _id
            userId
            name
            phone
            memo
            validUntil
        }
    }
`;


export const GET_USER_BY_PHONE = gql`
  query getUserByPhone($phone: String!) {
    getUserByPhone(phone: $phone) {
      _id
      userId
      name
      phone
      memo
      validUntil
    }
  }
`;

export const GET_USER_BY_NAME = gql`
  query getUserByName($name: String!) {
    getUserByName(name: $name) {
      _id
      userId
      name
      phone
      memo
      validUntil
    }
  }
`;


// 어드민 전용 callLogs 조회
export const GET_CALL_LOGS = gql`
    query GetCallLogs($start: Int!, $end: Int!) {
        getCallLogs(start: $start, end: $end) {
            _id
            timestamp
            userId {
                name
                phone
            }
            customerId {
            phone
            averageScore
            }
            memo
            score
        }
    }
`;

// queries.js
export const GET_CALL_LOGS_BY_PHONE = gql`
  query getCallLogByPhone($customerPhone: String!, $userId: String, $userPhone: String) {
    getCallLogByPhone(customerPhone: $customerPhone, userId: $userId, userPhone: $userPhone) {
      _id
      timestamp
      userId {
        name
        phone
      }
      customerId {
        phone
        averageScore
      }
      memo
      score
    }
  }
`;


export const GET_CUSTOMERS = gql`
    query GetCustomers($start: Int!, $end: Int!) {
        getCustomers(start: $start, end: $end) {
            _id
            phone
            averageScore
            totalCalls
        }
    }
`;

export const GET_CUSTOMER_BY_PHONE = gql`
  query getCustomerByPhone($searchPhone: String!, $userId: String, $phone: String) {
    getCustomerByPhone(userId: $userId, phone: $phone, searchPhone: $searchPhone) {
      customer {
        _id
        phone
        averageScore
        totalCalls
      }
      callLogs {
        _id
        score
        memo
        timestamp
        userId {
          userId
          phone
        }
      }
    }
  }
`;



