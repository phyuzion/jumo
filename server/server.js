// server.js
require('dotenv').config();
const express = require('express');
const cors = require('cors');
const { ApolloServer } = require('apollo-server-express');
const { 
  ApolloServerPluginLandingPageLocalDefault,
  ApolloServerPluginLandingPageProductionDefault 
} = require('apollo-server-core');

const jwt = require('jsonwebtoken');

const connectDB = require('./config/db');
const typeDefs = require('./graphql/typeDefs');
const resolvers = require('./graphql/resolvers');

async function startServer() {
  // 1) MongoDB 연결
  await connectDB();

  // 2) Express 앱
  const app = express();
  app.use(cors());
  app.use(express.json());

  // 3) ApolloServer 생성
  const server = new ApolloServer({
    typeDefs,
    resolvers,
    introspection: true,
    // Production(배포) 모드에서도 Landing Page를 활성화
    plugins: [
      // 1) 로컬 + 개발용 기본 페이지:
      // ApolloServerPluginLandingPageLocalDefault()
  
      // 2) 프로덕션 환경에서도 뜨도록
      ApolloServerPluginLandingPageProductionDefault({
        // 기본 안내 문구 또는 studio 링크 등 커스터마이징 가능
        footer: false
      })
    ],
    context: ({ req }) => {
      // --- 여기가 핵심: "어드민 JWT" 인증 체크 ---
      // Authorization: Bearer <token>
      const token = req.headers.authorization?.split(' ')[1];
      let isAdmin = false;

      if (token) {
        try {
          const decoded = jwt.verify(token, process.env.JWT_SECRET);
          // decoded = { adminId: 'admin', iat:..., exp:... }
          if (decoded.adminId) {
            isAdmin = true;
          }
        } catch (err) {
          // 토큰이 만료 or 유효하지 않음
          isAdmin = false;
        }
      }

      // context로 내려보내기
      return { isAdmin };
    },
  });

  // 4) ApolloServer와 Express 연결
  await server.start();
  server.applyMiddleware({ app, path: '/graphql' });

  // 5) 서버 리스닝
  const PORT = process.env.PORT || 4000;
  app.listen(PORT, () => {
    console.log(`✅ Server running on port ${PORT}`);
  });
}

startServer();
