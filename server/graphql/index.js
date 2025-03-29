// graphql/index.js

const { mergeTypeDefs, mergeResolvers } = require('@graphql-tools/merge');
const { GraphQLJSON } = require('graphql-type-json');
const { DateScalar } = require('./scalars/date');

// 도메인별 import
const adminTypeDefs = require('./admin/admin.typeDefs');
const adminResolvers = require('./admin/admin.resolvers');
const userTypeDefs = require('./user/user.typeDefs');
const userResolvers = require('./user/user.resolvers');
const phoneTypeDefs = require('./phone/phone.typeDefs');
const phoneResolvers = require('./phone/phone.resolvers');
const contentTypeDefs = require('./content/content.typeDefs');
const contentResolvers = require('./content/content.resolvers');
const notificationTypeDefs = require('./notification/notification.typeDefs');
const notificationResolvers = require('./notification/notification.resolvers');
const authTypeDefs = require('./auth/auth.typeDefs');
const authResolvers = require('./auth/auth.resolvers');
const versionTypeDefs = require('./version/version.typeDefs');
const versionResolvers = require('./version/version.resolvers');
const todayRecordTypeDefs = require('./todayRecord/todayRecord.typeDefs');
const todayRecordResolvers = require('./todayRecord/todayRecord.resolvers');
const regionTypeDefs = require('./region/region.typeDefs');
const regionResolvers = require('./region/region.resolvers');
const gradeTypeDefs = require('./grade/grade.typeDefs');
const gradeResolvers = require('./grade/grade.resolvers');  
const userTypeTypeDefs = require('./userType/userType.typeDefs');
const userTypeResolvers = require('./userType/userType.resolvers');

/*
  루트 스키마에 최소 1개씩 Query, Mutation 이 필요.
  이후 각 도메인에서 `extend type Query/Mutation` 형태로 확장
*/
const rootTypeDefs = `
  scalar Date

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
    user: User!
  }
`;

// 모든 typeDefs 합치기
const typeDefs = mergeTypeDefs([
  rootTypeDefs,
  adminTypeDefs,
  userTypeDefs,
  phoneTypeDefs,
  contentTypeDefs,
  notificationTypeDefs,
  authTypeDefs,
  versionTypeDefs,
  todayRecordTypeDefs,
  regionTypeDefs,
  gradeTypeDefs,
  userTypeTypeDefs,
]);

// 모든 resolvers 합치기
const resolvers = mergeResolvers([
  adminResolvers,
  userResolvers,
  phoneResolvers,
  {
    JSON: GraphQLJSON,
    Date: DateScalar,
  },
  contentResolvers,
  notificationResolvers,
  authResolvers,
  versionResolvers,
  todayRecordResolvers,
  regionResolvers,
  gradeResolvers,
  userTypeResolvers,
]);

module.exports = {
  typeDefs,
  resolvers,
};
