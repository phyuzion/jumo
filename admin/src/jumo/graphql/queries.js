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
 *     - region, settings, grade 추가
 *     - createdAt, validUntil 타입을 Date로 변경
 */
export const GET_ALL_USERS = gql`
  query {
    getAllUsers {
      id
      loginId
      name
      phoneNumber
      userType
      createdAt
      validUntil
      region
      grade
      settings
    }
  }
`;

/**
 * (2) 특정 유저 + 전화번호부 기록
 *     - user { region, settings, grade } 추가
 *     - createdAt, validUntil, records.createdAt 타입을 Date로 변경
 */
export const GET_USER_RECORDS = gql`
  query getUserRecords($userId: ID!) {
    getUserRecords(userId: $userId) {
      user {
        id
        loginId
        name
        phoneNumber
        userType
        createdAt
        validUntil
        region
        grade
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
 * - time 필드 타입을 Date로 변경
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
 * - records.createdAt 타입을 Date로 변경
 */
export const GET_PHONE_NUMBER = gql`
  query getPhoneNumber($phoneNumber: String!, $isRequested: Boolean) {
    getPhoneNumber(phoneNumber: $phoneNumber, isRequested: $isRequested) {
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
 * Grade 관련 쿼리
 */
export const GET_ALL_GRADES = gql`
  query {
    getGrades {
      name
      limit
    }
  }
`;

/**
 * Region 관련 쿼리
 */
export const GET_ALL_REGIONS = gql`
  query {
    getRegions {
      name
    }
  }
`;

/**
 * Content
 * - createdAt 타입을 Date로 변경
 */
export const GET_CONTENTS = gql`
  query getContents($type: String) {
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

/**
 * Notification
 * - validUntil, createdAt 타입을 Date로 변경
 */
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

export const GET_USER_TYPES = gql`
  query GetUserTypes {
    getUserTypes {
      name
    }
  }
`;
