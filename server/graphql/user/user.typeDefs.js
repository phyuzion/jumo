// graphql/user/user.typeDefs.js
const { gql } = require('apollo-server-express');

module.exports = gql`
  type User {
    id: ID!
    systemId: String!
    loginId: String!
    name: String
    phoneNumber: String
    type: Int
    createdAt: String
    validUntil: String
  }

  type CreateUserPayload {
    user: User!
    tempPassword: String!
  }

  type ChangePasswordPayload {
    success: Boolean!
    user: User
  }

  extend type Query {
    """
    (Admin 전용) 모든 유저 조회
    """
    getAllUsers: [User!]!

    """
    특정 유저 1명 조회 (Admin or 본인)
    """
    getUser(userId: ID!): User
  }

  extend type Mutation {
    """
    (Admin 전용) 유저 생성
    """
    createUser(phoneNumber: String!, name: String!): CreateUserPayload

    """
    유저 로그인 -> (accessToken, refreshToken)
    """
    userLogin(loginId: String!, password: String!, phoneNumber: String!): AuthPayload

    """
    유저 비밀번호 변경 (본인)
    """
    userChangePassword(oldPassword: String!, newPassword: String!): ChangePasswordPayload

    """
    (Admin 전용) 유저 정보 업데이트
    """
    updateUser(
      userId: ID!
      name: String
      phoneNumber: String
      validUntil: String
      type: Int
    ): User

    """
    (Admin 전용) 특정 유저 비밀번호 초기화
    """
    resetUserPassword(userId: ID!): String
  }
`;
