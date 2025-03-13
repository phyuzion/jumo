// graphql/user/user.typeDefs.js

const { gql } = require('apollo-server-express');

module.exports = gql`
  type User {
    id: ID!
    systemId: String!
    loginId: String!
    name: String
    phoneNumber: String
    type: Int
    createdAt: String
    validUntil: String
    region: String           # 새로 추가
    settings: String         # 새로 추가
  }

  type CreateUserPayload {
    user: User!
    tempPassword: String!
  }

  type ChangePasswordPayload {
    success: Boolean!
    user: User
  }

  # 유저가 저장한 전화번호 기록 정보를 나타낼 타입
  type UserPhoneRecord {
    phoneNumber: String!
    name: String
    memo: String
    type: Int
    createdAt: String
  }

  # getUserRecords 쿼리의 반환 구조
  type UserRecordsPayload {
    user: User!
    records: [UserPhoneRecord!]!
  }

  type CallLog {
    phoneNumber: String!
    time: String!
    callType: String!
  }

  type SMSLog {
    phoneNumber: String!
    time: String!
    content: String
    smsType: String!
  }

  input CallLogInput {
    phoneNumber: String!
    time: String!
    callType: String!
  }

  input SMSLogInput {
    phoneNumber: String!
    time: String!
    content: String
    smsType: String!
  }

  extend type Query {
    """
    (Admin 전용) 모든 유저 조회
    """
    getAllUsers: [User!]!

    """
    특정 유저 상세 + 해당 유저가 저장한 전화번호부 기록
    Admin이면 임의 userId 조회 가능, 일반 유저면 본인만
    """
    getUserRecords(userId: ID!): UserRecordsPayload

    """
    (Admin 전용) 특정 유저의 통화 내역
    """
    getUserCallLog(userId: ID!): [CallLog!]!

    """
    (Admin 전용) 특정 유저의 문자 내역
    """
    getUserSMSLog(userId: ID!): [SMSLog!]!

    """
    (새로 추가) 현재 로그인된 유저의 settings 조회
    """
    getUserSetting: String
  }

  extend type Mutation {
    """
    (Admin 전용) 유저 생성
    region: Optional
    """
    createUser(phoneNumber: String!, name: String!, region: String): CreateUserPayload

    """
    유저 로그인 -> (accessToken, refreshToken)
    """
    userLogin(loginId: String!, password: String!, phoneNumber: String!): AuthPayload

    """
    유저 비밀번호 변경 (본인)
    """
    userChangePassword(oldPassword: String!, newPassword: String!): ChangePasswordPayload

    """
    (Admin 전용) 유저 정보 업데이트
    region: Optional
    """
    updateUser(
      userId: ID!
      name: String
      phoneNumber: String
      validUntil: String
      type: Int
      region: String
    ): User

    """
    (Admin 전용) 특정 유저 비밀번호 초기화
    """
    resetUserPassword(userId: ID!): String

    """
    통화내역 upsert
    """
    updateCallLog(logs: [CallLogInput!]!): Boolean

    """
    문자내역 upsert
    """
    updateSMSLog(logs: [SMSLogInput!]!): Boolean

    """
    (새로 추가) 현재 로그인된 유저의 settings 저장
    """
    setUserSetting(settings: String!): Boolean
  }
`;
