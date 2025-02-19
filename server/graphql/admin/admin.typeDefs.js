// graphql/admin/admin.typeDefs.js
const { gql } = require('apollo-server-express');

module.exports = gql`
  type Admin {
    id: ID!
    username: String!
  }

  extend type Mutation {
    """
    Admin 생성
    """
    createAdmin(username: String!, password: String!): Admin

    """
    Admin 로그인 -> (accessToken, refreshToken)
    """
    adminLogin(username: String!, password: String!): AuthPayload
  }
`;
