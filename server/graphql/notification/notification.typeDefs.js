// graphql/notification/notification.typeDefs.js
const { gql } = require('apollo-server-express');

module.exports = gql`
  type Notification {
    id: ID!
    title: String!
    message: String
    validUntil: String
    createdAt: String
  }

  extend type Query {
    getNotifications: [Notification!]!
  }

  extend type Mutation {
    createNotification(title: String!, message: String!, validUntil: String): Notification
  }
`;
