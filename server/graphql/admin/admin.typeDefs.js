// graphql/admin/admin.typeDefs.js
const { gql } = require('apollo-server-express');

module.exports = gql`
  type Admin {
    id: ID!
    username: String!
  }

  type SummaryPayload {
    usersCount: Int!
    phoneCount: Int!
    dangerPhoneCount: Int!
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

  extend type Query {
    """
    (Admin 전용) 대시보드 요약 정보
    - 총 유저 수
    - 총 전화번호 문서 수
    - type=99(위험) 전화번호 문서 수
    """
    getSummary: SummaryPayload!
  }
`;
