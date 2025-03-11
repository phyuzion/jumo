// src/graphql/queries.js
import { gql } from '@apollo/client';

export const GET_SUMMARY = gql`
  query {
    getSummary {
      usersCount
      phoneCount
      dangerPhoneCount
    }
  }
`;

// (1) 모든 유저 조회
export const GET_ALL_USERS = gql`
  query {
    getAllUsers {
      id
      systemId
      loginId
      name
      phoneNumber
      type
      createdAt
      validUntil
    }
  }
`;

// (2) 특정 유저 + 전화번호부 기록
export const GET_USER_RECORDS = gql`
  query getUserRecords($userId: ID!) {
    getUserRecords(userId: $userId) {
      user {
        id
        systemId
        loginId
        name
        phoneNumber
        type
        createdAt
        validUntil
      }
      records {
        phoneNumber
        name
        memo
        type
        createdAt
      }
    }
  }
`;

export const GET_USER_CALL_LOG = gql`
  query getUserCallLog($userId: ID!) {
    getUserCallLog(userId: $userId) {
      phoneNumber
      time
      callType
    }
  }
`;

export const GET_USER_SMS_LOG = gql`
  query getUserSMSLog($userId: ID!) {
    getUserSMSLog(userId: $userId) {
      phoneNumber
      time
      content
      smsType
    }
  }
`;


// (A) 전화번호로 1개 문서 조회
export const GET_PHONE_NUMBER = gql`
  query getPhoneNumber($phoneNumber: String!) {
    getPhoneNumber(phoneNumber: $phoneNumber) {
      id
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
`;

export const GET_CONTENTS = gql`
  query getContents($type: Int) {
    getContents(type: $type) {
      id
      userId
      type
      title
      createdAt
    }
  }
`;

export const GET_SINGLE_CONTENT = gql`
  query getSingleContent($contentId: ID!) {
    getSingleContent(contentId: $contentId) {
      id
      userId
      type
      title
      createdAt
      # content: Delta(JSON) -> we'll get it as an object string?
      content
      comments {
        userId
        comment
        createdAt
      }
    }
  }
`;

export const GET_NOTIFICATIONS = gql`
  query getNotifications {
    getNotifications {
      id
      title
      message
      validUntil
      createdAt
      targetUserId
    }
  }
`;