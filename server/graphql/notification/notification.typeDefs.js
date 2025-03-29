// graphql/notification/notification.typeDefs.js
const { gql } = require('apollo-server-express');

module.exports = gql`
  type Notification {
    id: ID!
    title: String!
    message: String
    validUntil: String
    createdAt: String
    targetUserId: ID
  }

  extend type Query {
    """
    알림 목록
    - 로그인 사용자라면 "해당 유저 전용" + "전역(null) 알림" 모두
    - 로그인 안 했다면 "전역 알림"만
    """
    getNotifications: [Notification!]!
  }

  extend type Mutation {
    """
    어드민이 알림 생성
    - userId: 특정 유저에게만 (null이면 전역)
    - validUntil: 없으면 기본 1일
    """
    createNotification(
      title: String!,
      message: String!,
      validUntil: String,
      userId: ID
    ): Notification
  }
`;
