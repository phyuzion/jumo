const { gql } = require('apollo-server-express');

const typeDefs = gql`
  # ----------------------
  #       Admin
  # ----------------------
  type Admin {
    _id: ID!
    adminId: String!
    createdAt: String
  }

  type AdminLoginResponse {
    token: String
    adminId: String
  }

  # ----------------------
  #       User
  # ----------------------
  type User {
    _id: ID!
    userId: String!
    phone: String!
    name: String
    memo: String
    validUntil: String
    createdAt: String
  }

  # ----------------------
  #     Customer
  # ----------------------
  type Customer {
    _id: ID!
    phone: String!
    name: String
    totalCalls: Int
    averageScore: Float
    createdAt: String
  }

  # ----------------------
  #     CallLog
  # ----------------------
  type CallLog {
    _id: ID!
    customerId: Customer
    userId: User
    timestamp: String
    score: Int
    memo: String
  }

  type CallLogCreationResult {
    callLog: CallLog
    customer: Customer
  }

  type CustomerResult {
    customer: Customer
    callLogs: [CallLog]
  }

  # ============================
  #         Query
  # ============================
  type Query {
    # [어드민 전용] 유저 정보 개별 조회
    getUserByPhone(phone: String!): User
    getUserByName(name: String!): [User]

    # [어드민 전용] 유저 목록 (기존 getUsers 대체 or 보완)
    getUsers(phone: String, name: String): [User]

    # [공개 or 유저용] 고객 조회 (전화번호)
    getCustomerByPhone(phone: String!): [CustomerResult]

    # [공개 or 유저용] 고객 조회 (이름)
    getCustomerByName(name: String!): [CustomerResult]

    # CallLogs 관련 (공개/유저/어드민 공용으로 쓸 수도 있음)
    getTotalCallLogs(customerId: ID!): Int
    getCallLogs(customerId: ID!, limit: Int): [CallLog]
    getCallLogByID(logId: ID!): CallLog
  }

  # ============================
  #       Mutation
  # ============================
  type Mutation {
    # [어드민] Admin 계정 생성
    createAdmin(adminId: String!, password: String!): Admin
    # [어드민] Admin 로그인
    adminLogin(adminId: String!, password: String!): AdminLoginResponse

    # [어드민] 유저 생성 / 수정
    createUser(phone: String!, name: String, memo: String, validUntil: String): User
    updateUser(userId: String!, phone: String, name: String, memo: String, validUntil: String): User

    # [클라이언트/유저] 로그인
    clientLogin(userId: String!, phone: String!): Boolean

    # [클라이언트/유저] 콜로그 생성 / 수정
    createCallLog(userId: String!, phone: String!, customerPhone: String!, score: Int, memo: String): CallLogCreationResult
    updateCallLog(logId: ID!, userId: String!, phone: String!, score: Int, memo: String): CallLog
  }
`;

module.exports = typeDefs;
