// typeDefs.js
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
    userId: String!      # 6글자 자동
    phone: String!       # 고유
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
    totalCalls: Int
    averageScore: Float
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

  # 콜로그 생성 시 반환
  type CallLogCreationResult {
    callLog: CallLog
    customer: Customer
  }

  # 고객 + 콜로그 묶음
  type CustomerResult {
    customer: Customer
    callLogs: [CallLog]
  }

  type SummaryResult {
    callLogsCount: Int
    usersCount: Int
    customersCount: Int
  }

  # ============================
  #         Query
  # ============================
  type Query {
    # [어드민 전용] ----------------------------------
    getUserByPhone(phone: String!): [User]
    getUserByName(name: String!): [User]
    getUsers(phone: String, name: String): [User]


    # 새로 추가 (어드민 리스트 조회)
    getUserList(start: Int!, end: Int!): [User]
    getCallLogs(start: Int!, end: Int!): [CallLog]
    getCustomers(start: Int!, end: Int!): [Customer]


    # [유저 전용] => (userId, phone) 인증
    getCustomerByPhone(
      userId: String!,
      phone: String!,
      searchPhone: String!
    ): [CustomerResult]

    getCallLogByID(
      userId: String!,
      phone: String!,
      logId: ID!
    ): CallLog

    # 유저 콜로그 조회 (start, end) - 통합
    getCallLogsForUser(
      userId: String!,
      phone: String!,
      start: Int!,
      end: Int!
    ): [CallLog]

    getSummary: SummaryResult
  }

  # ============================
  #       Mutation
  # ============================
  type Mutation {
    # [어드민] ----------------------------------------
    createAdmin(adminId: String!, password: String!): Admin
    adminLogin(adminId: String!, password: String!): AdminLoginResponse

    # [어드민] 유저 생성 / 수정
    createUser(phone: String!, name: String, memo: String, validUntil: String): User
    updateUser(userId: String!, phone: String, name: String, memo: String, validUntil: String): User

    # [클라이언트/유저] --------------------------------
    clientLogin(userId: String!, phone: String!): Boolean

    createCallLog(
      userId: String!,
      phone: String!,
      customerPhone: String!,
      score: Int,
      memo: String
    ): CallLogCreationResult

    updateCallLog(
      logId: ID!,
      userId: String!,
      phone: String!,
      score: Int,
      memo: String
    ): CallLog
  }
`;

module.exports = typeDefs;
