// graphql/phone/phone.typeDefs.js
const { gql } = require('apollo-server-express');

module.exports = gql`
  type Record {
    userId: ID!
    name: String
    memo: String
    createdAt: String
  }

  type PhoneNumber {
    id: ID!
    phoneNumber: String!
    type: Int
    records: [Record!]!
  }

  input RecordInput {
    phoneNumber: String!
    name: String
    memo: String
  }

  extend type Query {
    getPhoneNumber(phoneNumber: String!): PhoneNumber
    getPhoneNumbersByType(type: Int!): [PhoneNumber!]!
  }

  extend type Mutation {
    uploadPhoneRecords(records: [RecordInput!]!): Boolean
    updatePhoneRecordMemo(phoneNumber: String!, memo: String!): Boolean
  }
`;
