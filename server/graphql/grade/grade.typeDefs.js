const { gql } = require('apollo-server-express');

const typeDefs = gql`
  type Grade {
    name: String!
    limit: Int!
  }

  extend type Query {
    getGrades: [Grade!]!
  }

  extend type Mutation {
    addGrade(name: String!, limit: Int!): Grade!
  }
`;

module.exports = typeDefs; 