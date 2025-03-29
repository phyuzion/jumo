const { gql } = require('apollo-server-express');

const typeDefs = gql`
  type TodayRecord {
    id: ID!
    phoneNumber: String!
    userName: String!
    userType: String!
    callType: String!
    createdAt: String!
  }

  extend type Query {
    getTodayRecord(phoneNumber: String!): [TodayRecord!]!
  }
`;

module.exports = typeDefs; 