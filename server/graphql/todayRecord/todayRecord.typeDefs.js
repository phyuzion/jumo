const { gql } = require('apollo-server-express');

const typeDefs = gql`
  type TodayRecord {
    id: ID!
    phoneNumber: String!
    userName: String!
    userType: Int!
    createdAt: String!
  }

  extend type Query {
    getTodayRecord(phoneNumber: String!): [TodayRecord!]!
  }
`;

module.exports = typeDefs; 