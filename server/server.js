// server.js
require('dotenv').config();
const express = require('express');
const cors = require('cors');
const { ApolloServer } = require('apollo-server-express');
const jwt = require('jsonwebtoken');
const rateLimit = require('express-rate-limit');

const {
  ApolloServerPluginLandingPageProductionDefault
} = require('apollo-server-core');



const connectDB = require('./config/db');
const { typeDefs, resolvers } = require('./graphql'); // 통합된 것 import


const SECRET_KEY = process.env.JWT_SECRET || 'someRandomSecretKey';
const PORT = process.env.PORT || 4000;


async function getUserFromToken(token) {
  if (!token) return null;
  try {
    const realToken = token.replace('Bearer ', ''); // "Bearer " 제거
    const decoded = jwt.verify(realToken, SECRET_KEY);
    return decoded; // { adminId? , userId? , iat, exp, ... }
  } catch (e) {
    return null;
  }
}

async function startServer() {
  // 1) MongoDB 연결
  await connectDB();

  // 2) Express 앱
  const app = express();
  app.use(cors());
  app.use(express.json());


  // 초당 1회 요청 제한 (windowMs: 1000ms, max:1)
  const limiter = rateLimit({
    windowMs: 1000, // 1초
    max: 1,         // 최대 1회
    message: '너무 많은 요청입니다. 잠시 후 다시 시도해주세요.',
  });
  // /graphql 라우트에만 적용 (전역 적용도 가능)
  //app.use('/graphql', limiter);

  // 3) ApolloServer 생성
  const server = new ApolloServer({
    typeDefs,
    resolvers,
    introspection: true, // 스키마 탐색 가능하게 설정
    plugins: [
      ApolloServerPluginLandingPageProductionDefault({
        embed: true, // 스튜디오 창을 강제 활성화
        footer: false
      })
    ],
    context: async ({ req }) => {
      const authHeader = req.headers.authorization || '';
      const tokenData = await getUserFromToken(authHeader);
      // context에 tokenData와 req를 넘겨서 resolvers에서 사용
      return { tokenData, req };
    },
  });


  // 4) ApolloServer와 Express 연결
  await server.start();
  server.applyMiddleware({ app, path: '/graphql' });

  // 5) 서버 리스닝
  const PORT = process.env.PORT || 4000;
  app.listen(PORT, () => {
    console.log(`✅ Server running on port ${PORT}`);
    console.log(`GraphQL endpoint: http://localhost:${PORT}/graphql`);
  });
}

startServer();
