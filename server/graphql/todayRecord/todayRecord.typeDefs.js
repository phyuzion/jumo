const { gql } = require('apollo-server-express');

const typeDefs = gql`
  type TodayRecord {
    id: ID!
    phoneNumber: String!
    userName: String!
    userType: String!
    callType: String!
    time: String!
  }

  extend type Query {
    getTodayRecord(phoneNumber: String!): [TodayRecord!]!
  }
`;

module.exports = typeDefs; 