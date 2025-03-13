import { gql } from '@apollo/client';

/**
 * (Admin) 대시보드 요약
 */
export const GET_SUMMARY = gql`
  query {
    getSummary {
      usersCount
      phoneCount
      dangerPhoneCount
    }
  }
`;

/**
 * (1) 모든 유저 조회
 *     - region, settings 추가
 */
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
      region
      settings
    }
  }
`;

/**
 * (2) 특정 유저 + 전화번호부 기록
 *     - user { region, settings } 추가
 */
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
        region
        settings
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

/**
 * (Admin) 유저 통화 / 문자 조회
 */
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

/**
 * (A) 전화번호로 1개 문서 조회
 */
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

/**
 * Content
 *  - userName, userRegion 추가
 */
export const GET_CONTENTS = gql`
  query getContents($type: Int) {
    getContents(type: $type) {
      id
      userId
      userName
      userRegion
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
      userName
      userRegion
      type
      title
      createdAt
      content
      comments {
        userId
        userName
        userRegion
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

/**
 * APK 버전 조회
 */
export const CHECK_APK_VERSION = gql`
  query {
    checkAPKVersion
  }
`;
