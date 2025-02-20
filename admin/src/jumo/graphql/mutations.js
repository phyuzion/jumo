import { gql } from '@apollo/client';


// (1) Admin 로그인
export const ADMIN_LOGIN = gql`
  mutation adminLogin($username: String!, $password: String!) {
    adminLogin(username: $username, password: $password) {
      accessToken
      refreshToken
    }
  }
`;

// (1) 유저 생성
export const CREATE_USER = gql`
  mutation createUser($phoneNumber: String!, $name: String!) {
    createUser(phoneNumber: $phoneNumber, name: $name) {
      user {
        id
        systemId
        loginId
        name
        phoneNumber
        type
        validUntil
      }
      tempPassword
    }
  }
`;

// (2) 유저 정보 업데이트
export const UPDATE_USER = gql`
  mutation updateUser(
    $userId: ID!
    $name: String
    $phoneNumber: String
    $validUntil: String
    $type: Int
  ) {
    updateUser(
      userId: $userId
      name: $name
      phoneNumber: $phoneNumber
      validUntil: $validUntil
      type: $type
    ) {
      id
      systemId
      loginId
      name
      phoneNumber
      type
      validUntil
    }
  }
`;

// (3) 유저 비밀번호 리셋
export const RESET_USER_PASSWORD = gql`
  mutation resetUserPassword($userId: ID!) {
    resetUserPassword(userId: $userId)
  }
`;


// (A) 여러 Record 업서트 (하나만 보낼 수도 있음)
export const UPSERT_PHONE_RECORDS = gql`
  mutation upsertPhoneRecords($records: [PhoneRecordInput!]!) {
    upsertPhoneRecords(records: $records)
  }
`;
