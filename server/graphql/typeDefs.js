// graphql/typeDefs.js
const { gql } = require('apollo-server-express');

const typeDefs = gql`
  """
  Admin 타입
  """
  type Admin {
    id: ID!
    username: String!
  }

  """
  User 타입
  """
  type User {
    id: ID!
    systemId: String!
    loginId: String!
    name: String
    phoneNumber: String
    type: Int
    createdAt: String
    validUntil: String
  }

  """
  유저 생성 후 반환되는 데이터 구조
  """
  type CreateUserPayload {
    user: User!
    tempPassword: String!  # 임시 비번
  }

  """
  전화번호부 하나의 레코드
  """
  type Record {
    userId: ID!
    name: String
    memo: String
    createdAt: String
  }

  """
  전화번호부 구조
  """
  type PhoneNumber {
    id: ID!
    phoneNumber: String!
    type: Int
    records: [Record!]!
  }

  """
  로그인/리프레시 응답 토큰
  """
  type AuthPayload {
    accessToken: String!
    refreshToken: String!
  }

  """
  전화번호 업로드시 사용될 input
  """
  input RecordInput {
    phoneNumber: String!
    name: String
    memo: String
  }

  type Query {
    """
    (Admin 전용) 모든 유저 조회
    """
    getAllUsers: [User!]!

    """
    특정 유저 1명 조회 (Admin or 본인만 가능)
    """
    getUser(userId: ID!): User

    """
    (Admin, User) 특정 전화번호 조회
    """
    getPhoneNumber(phoneNumber: String!): PhoneNumber

    """
    (Admin, User) 타입으로 전화번호 목록 조회
    """
    getPhoneNumbersByType(type: Int!): [PhoneNumber!]!
  }

  type Mutation {
    # ========== Admin 관련 ==========
    createAdmin(username: String!, password: String!): Admin
    adminLogin(username: String!, password: String!): AuthPayload

    # ========== User 관련 ==========
    createUser(phoneNumber: String!, name: String!): CreateUserPayload

    """
    유저 로그인 -> accessToken + refreshToken 반환
    """
    userLogin(loginId: String!, password: String!, phoneNumber: String!): AuthPayload

    """
    유저 비밀번호 변경 (본인)
    """
    userChangePassword(oldPassword: String!, newPassword: String!): User

    """
    (Admin 전용) 유저 정보 업데이트
    - userId: 대상 유저
    - name, phoneNumber, validUntil, type 등 부분 업데이트
    """
    updateUser(
      userId: ID!
      name: String
      phoneNumber: String
      validUntil: String
      type: Int
    ): User

    """
    (Admin 전용) 특정 유저의 비밀번호를 리셋(임시비번)으로 교체
    """
    resetUserPassword(userId: ID!): String

    # ========== 토큰 재발급 ==========
    refreshToken(refreshToken: String!): AuthPayload

    # ========== 전화번호부 관련 ==========
    uploadPhoneRecords(records: [RecordInput!]!): Boolean

    """
    메모만 수정(기존 전화번호 + 본인 업로드한 record 대상)
    """
    updatePhoneRecordMemo(phoneNumber: String!, memo: String!): Boolean
  }
`;

module.exports = typeDefs;
