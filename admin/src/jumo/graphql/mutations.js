import { gql } from '@apollo/client';

/**
 * 1) Admin 로그인
 */
export const ADMIN_LOGIN = gql`
  mutation adminLogin($username: String!, $password: String!) {
    adminLogin(username: $username, password: $password) {
      accessToken
      refreshToken
    }
  }
`;

/**
 * 2) 유저 생성
 *    - region, grade 필드 추가
 */
export const CREATE_USER = gql`
  mutation createUser(
    $loginId: String!
    $phoneNumber: String!
    $name: String!
    $userType: String
    $region: String
    $grade: String
  ) {
    createUser(
      loginId: $loginId
      phoneNumber: $phoneNumber
      name: $name
      userType: $userType
      region: $region
      grade: $grade
    ) {
      user {
        id
        loginId
        name
        phoneNumber
        userType
        validUntil
        region
        grade
        settings
      }
      tempPassword
    }
  }
`;

/**
 * 3) 유저 정보 업데이트
 *    - region, grade 필드 추가
 */
export const UPDATE_USER = gql`
  mutation updateUser(
    $userId: ID!
    $name: String
    $phoneNumber: String
    $validUntil: String
    $userType: String
    $region: String
    $grade: String
  ) {
    updateUser(
      userId: $userId
      name: $name
      phoneNumber: $phoneNumber
      validUntil: $validUntil
      userType: $userType
      region: $region
      grade: $grade
    ) {
      id
      loginId
      name
      phoneNumber
      userType
      validUntil
      region
      grade
      settings
    }
  }
`;

/**
 * 4) 유저 비밀번호 리셋
 */
export const RESET_USER_PASSWORD = gql`
  mutation resetUserPassword($userId: ID!) {
    resetUserPassword(userId: $userId)
  }
`;

/**
 * (A) 여러 Phone Record 업서트
 */
export const UPSERT_PHONE_RECORDS = gql`
  mutation upsertPhoneRecords($records: [PhoneRecordInput!]!) {
    upsertPhoneRecords(records: $records)
  }
`;

/**
 * Content 관련
 * - createContent / updateContent / deleteContent
 * - createReply / deleteReply
 * - uploadContentImage (Quill 에디터용)
 * 
 * 새로운 필드 userName / userRegion, 
 * 댓글(Comment)에도 userName / userRegion 추가
 */
export const CREATE_CONTENT = gql`
  mutation createContent($type: String, $title: String, $content: JSON!) {
    createContent(type: $type, title: $title, content: $content) {
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

export const UPDATE_CONTENT = gql`
  mutation updateContent(
    $contentId: ID!
    $title: String
    $content: JSON
    $type: String
  ) {
    updateContent(
      contentId: $contentId
      title: $title
      content: $content
      type: $type
    ) {
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
        userName
        userRegion
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

/**
 * Notification 관련
 */
export const CREATE_NOTIFICATION = gql`
  mutation createNotification(
    $title: String!
    $message: String!
    $validUntil: String
    $userId: ID
  ) {
    createNotification(
      title: $title
      message: $message
      validUntil: $validUntil
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

/**
 * APK 업로드 (Version API)
 */
export const UPLOAD_APK = gql`
  mutation uploadAPK($version: String!, $file: Upload!) {
    uploadAPK(version: $version, file: $file)
  }
`;

/**
 * Grade 관련 뮤테이션
 */
export const ADD_GRADE = gql`
  mutation addGrade($name: String!, $limit: Int!) {
    addGrade(name: $name, limit: $limit) {
      name
      limit
    }
  }
`;

/**
 * Region 관련 뮤테이션
 */
export const ADD_REGION = gql`
  mutation addRegion($name: String!) {
    addRegion(name: $name) {
      name
    }
  }
`;

/**
 * Content 관련
 * - createContent / updateContent / deleteContent
 * - createReply / deleteReply
 * - uploadContentImage (Quill 에디터용)
 */
export const UPLOAD_CONTENT_IMAGE = gql`
  mutation uploadContentImage($file: Upload!) {
    uploadContentImage(file: $file)
  }
`;
