const { gql } = require('apollo-server-express');

const typeDefs = gql`
  type Region {
    name: String!
  }

  extend type Query {
    getRegions: [Region!]!
  }

  extend type Mutation {
    addRegion(name: String!): Region!
  }
`;

module.exports = typeDefs; 