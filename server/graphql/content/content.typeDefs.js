const { gql } = require('apollo-server-express');

module.exports = gql`
  scalar JSON

  # 댓글: user -> User
  type Comment {
    user: User
    comment: String
    createdAt: String
  }

  type Content {
    id: ID!
    user: User
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
    createContent(type: Int, title: String, content: JSON!): Content
    updateContent(contentId: ID!, title: String, content: JSON, type: Int): Content
    deleteContent(contentId: ID!): Boolean

    createReply(contentId: ID!, comment: String!): Content
    deleteReply(contentId: ID!, index: Int!): Boolean
  }
`;
