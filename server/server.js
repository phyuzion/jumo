// server.js
require('dotenv').config();
const express = require('express');
const cors = require('cors');
const { ApolloServer } = require('apollo-server-express');
const jwt = require('jsonwebtoken');

const {
  ApolloServerPluginLandingPageProductionDefault
} = require('apollo-server-core');



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
    introspection: true, // 스키마 탐색 가능하게 설정
    plugins: [
      ApolloServerPluginLandingPageProductionDefault({
        embed: true, // 스튜디오 창을 강제 활성화
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
    console.log(`GraphQL endpoint: http://localhost:${PORT}/graphql`);
  });
}

startServer();
