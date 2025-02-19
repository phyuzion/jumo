// graphql/index.js

const { mergeTypeDefs, mergeResolvers } = require('@graphql-tools/merge');

// 도메인별 import
const adminTypeDefs = require('./admin/admin.typeDefs');
const adminResolvers = require('./admin/admin.resolvers');
const userTypeDefs = require('./user/user.typeDefs');
const userResolvers = require('./user/user.resolvers');
const phoneTypeDefs = require('./phone/phone.typeDefs');
const phoneResolvers = require('./phone/phone.resolvers');
const contentTypeDefs = require('./content/content.typeDefs');
const contentResolvers = require('./content/content.resolvers');

/*
  루트 스키마에 최소 1개씩 Query, Mutation 이 필요.
  이후 각 도메인에서 `extend type Query/Mutation` 형태로 확장
*/
const rootTypeDefs = `
  type Query {
    _dummy: String
  }

  type Mutation {
    _dummy: String
  }

  # 필요하다면 공통 타입도 여기에 (ex. AuthPayload)
  type AuthPayload {
    accessToken: String!
    refreshToken: String!
  }
`;

// 모든 typeDefs 합치기
const typeDefs = mergeTypeDefs([
  rootTypeDefs,
  adminTypeDefs,
  userTypeDefs,
  phoneTypeDefs,
  contentTypeDefs,
]);

// 모든 resolvers 합치기
const resolvers = mergeResolvers([
  adminResolvers,
  userResolvers,
  phoneResolvers,
  contentResolvers,
]);

module.exports = {
  typeDefs,
  resolvers,
};
