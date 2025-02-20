// graphql/auth/auth.typeDefs.js
const { gql } = require('apollo-server-express');

module.exports = gql`
  extend type Mutation {
    """
    Refresh Token으로 새 Access/Refresh 토큰을 발급
    만료되었거나 무효하면 에러
    """
    refreshToken(refreshToken: String!): AuthPayload
  }
`;
