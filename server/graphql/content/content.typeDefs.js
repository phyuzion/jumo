// graphql/content/content.typeDefs.js
const { gql } = require('apollo-server-express');

module.exports = gql`
  type Comment {
    userId: ID!
    comment: String
    createdAt: String
  }

  type Content {
    id: ID!
    userId: ID!
    type: Int
    title: String
    content: String
    createdAt: String
    comments: [Comment!]!
  }

  extend type Query {
    getContents(type: Int): [Content!]!
    getSingleContent(contentId: ID!): Content
  }

  extend type Mutation {
    createContent(type: Int, title: String, content: String!): Content
    updateContent(contentId: ID!, title: String, content: String): Content
    deleteContent(contentId: ID!): Boolean

    createReply(contentId: ID!, comment: String!): Content
    deleteReply(contentId: ID!, index: Int!): Boolean
  }
`;
