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

    # 새 필드
    region: String
  }

  type CreateUserPayload {
    user: User!
    tempPassword: String!
  }

  type ChangePasswordPayload {
    success: Boolean!
    user: User
  }

  type UserPhoneRecord {
    phoneNumber: String!
    name: String
    memo: String
    type: Int
    createdAt: String
  }

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
    getAllUsers: [User!]!
    getUserRecords(userId: ID!): UserRecordsPayload
    getUserCallLog(userId: ID!): [CallLog!]!
    getUserSMSLog(userId: ID!): [SMSLog!]!
  }

  extend type Mutation {
    createUser(phoneNumber: String!, name: String!): CreateUserPayload
    userLogin(loginId: String!, password: String!, phoneNumber: String!): AuthPayload
    userChangePassword(oldPassword: String!, newPassword: String!): ChangePasswordPayload

    updateUser(
      userId: ID!
      name: String
      phoneNumber: String
      validUntil: String
      type: Int
    ): User

    resetUserPassword(userId: ID!): String

    updateCallLog(logs: [CallLogInput!]!): Boolean
    updateSMSLog(logs: [SMSLogInput!]!): Boolean
  }
`;
