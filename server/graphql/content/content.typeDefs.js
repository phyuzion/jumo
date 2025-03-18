// graphql/content/content.typeDefs.js
const { gql } = require('apollo-server-express');

module.exports = gql`
  scalar JSON

  type Comment {
    userId: String
    userName: String
    userRegion: String
    comment: String
    createdAt: String
  }

  type Content {
    id: ID!
    userId: String!
    userName: String!
    userRegion: String!
    type: Int!
    title: String!
    content: JSON!
    createdAt: String!
    comments: [Comment!]!
  }

  extend type Query {
    """
    게시판 목록 조회 (type으로 필터링 가능)
    content, comments 필드는 제외
    """
    getContents(type: Int): [Content!]!

    """
    게시글 상세 조회
    """
    getSingleContent(contentId: ID!): Content!
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
