// graphql/content/content.typeDefs.js
const { gql } = require('apollo-server-express');

module.exports = gql`
  scalar JSON

  type Comment {
    userId: String!
    comment: String
    createdAt: String
  }

  type Content {
    id: ID!
    userId: String
    type: Int
    title: String
    createdAt: String
    content: JSON
    comments: [Comment!]!
  }

  extend type Query {
    getContents(type: Int): [Content!]!
    getSingleContent(contentId: ID!): Content
  }

  extend type Mutation {
    """
    content: JSON 으로 전송 가능
    클라이언트에서 Delta 객체 통째로 전송 가능
    """
    createContent(type: Int, title: String, content: JSON!): Content
    updateContent(contentId: ID!, title: String, content: JSON, type: Int): Content
    deleteContent(contentId: ID!): Boolean

    createReply(contentId: ID!, comment: String!): Content
    deleteReply(contentId: ID!, index: Int!): Boolean
  }
`;
