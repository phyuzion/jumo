// graphql/phone/phone.typeDefs.js
const { gql } = require('apollo-server-express');

module.exports = gql`
  type Record {
    userName: String
    userType: Int
    name: String
    memo: String
    type: Int
    createdAt: String
  }

  type PhoneNumber {
    id: ID!
    phoneNumber: String!
    type: Int
    blockCount: Int!
    records: [Record!]!
  }

  type BlockNumber {
    phoneNumber: String!
    blockCount: Int!
  }

  # 업서트 입력
  input PhoneRecordInput {
    phoneNumber: String!
    userName: String
    userType: Int
    name: String
    memo: String
    type: Int
    createdAt: String
  }

  extend type Query {
    getPhoneNumber(phoneNumber: String!): PhoneNumber
    getPhoneNumbersByType(type: Int!): [PhoneNumber!]!
    getMyRecords: [UserPhoneRecord!]!
    getBlockNumbers(count: Int!): [BlockNumber!]!
  }

  extend type Mutation {
    """
    여러 번호(레코드) 업서트
    - 없으면 새로 생성, 있으면 수정
    """
    upsertPhoneRecords(records: [PhoneRecordInput!]!): Boolean
  }
`;
