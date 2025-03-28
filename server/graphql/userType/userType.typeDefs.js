const { gql } = require('apollo-server-express');

const typeDefs = gql`
  type UserType {
    name: String!
  }

  extend type Query {
    getUserTypes: [UserType!]!
  }

  extend type Mutation {
    addUserType(name: String!): UserType!
  }
`;

module.exports = typeDefs; 