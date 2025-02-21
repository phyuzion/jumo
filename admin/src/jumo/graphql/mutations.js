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

export const CREATE_CONTENT = gql`
  mutation createContent($type: Int, $title: String, $content: JSON!) {
    createContent(type: $type, title: $title, content: $content) {
      id
      userId
      type
      title
      createdAt
      content
      comments {
        userId
        comment
        createdAt
      }
    }
  }
`;

export const UPDATE_CONTENT = gql`
  mutation updateContent($contentId: ID!, $title: String, $content: JSON, $type: Int) {
    updateContent(contentId: $contentId, title: $title, content: $content, type: $type) {
      id
      userId
      type
      title
      createdAt
      content
      comments {
        userId
        comment
        createdAt
      }
    }
  }
`;

export const DELETE_CONTENT = gql`
  mutation deleteContent($contentId: ID!) {
    deleteContent(contentId: $contentId)
  }
`;

export const CREATE_REPLY = gql`
  mutation createReply($contentId: ID!, $comment: String!) {
    createReply(contentId: $contentId, comment: $comment) {
      id
      comments {
        userId
        comment
        createdAt
      }
    }
  }
`;

export const DELETE_REPLY = gql`
  mutation deleteReply($contentId: ID!, $index: Int!) {
    deleteReply(contentId: $contentId, index: $index)
  }
`;


export const CREATE_NOTIFICATION = gql`
  mutation createNotification(
    $title: String!,
    $message: String!,
    $validUntil: String,
    $userId: ID
  ) {
    createNotification(
      title: $title,
      message: $message,
      validUntil: $validUntil,
      userId: $userId
    ) {
      id
      title
      message
      validUntil
      createdAt
      targetUserId
    }
  }
`;