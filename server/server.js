// server.js
require('dotenv').config();
const express = require('express');
const cors = require('cors');
const { ApolloServer } = require('apollo-server-express');
const { graphqlUploadExpress } = require('graphql-upload');
const jwt = require('jsonwebtoken');
const rateLimit = require('express-rate-limit');
const { ApolloServerPluginLandingPageProductionDefault } = require('apollo-server-core');

const connectDB = require('./config/db');
const { typeDefs, resolvers } = require('./graphql');

const SECRET_KEY = process.env.JWT_SECRET || 'someRandomSecretKey';
const PORT = process.env.PORT || 4000;

async function getUserFromToken(token) {
  if (!token) return null;
  try {
    const realToken = token.replace('Bearer ', '');
    const decoded = jwt.verify(realToken, SECRET_KEY);
    return decoded;
  } catch (e) {
    return null;
  }
}

async function startServer() {
  await connectDB();

  const app = express();
  app.use(cors());
  app.use(express.json({ limit: '100mb' }));
  app.use(express.urlencoded({ limit: '100mb', extended: true }));

  // 1) graphqlUploadExpress
  app.use(graphqlUploadExpress());

  // 2) 정적 경로: /download -> /var/data/public_downloads
  //    (퍼시스턴트 디스크가 /var/data 에 마운트되었다고 가정)
  app.use('/download', express.static('/var/data/public_downloads'));
  
  // 3) 정적 경로: /contents/images -> /var/data/contents/images
  app.use('/contents/images', express.static('/var/data/contents/images'));

  const limiter = rateLimit({
    windowMs: 1000,
    max: 1,
    message: '너무 많은 요청입니다. 잠시 후 다시 시도해주세요.',
  });
  // app.use('/graphql', limiter);

  const server = new ApolloServer({
    typeDefs,
    resolvers,
    introspection: true,
    plugins: [
      ApolloServerPluginLandingPageProductionDefault({
        embed: true,
        footer: false
      })
    ],
    context: async ({ req }) => {
      const authHeader = req.headers.authorization || '';
      const tokenData = await getUserFromToken(authHeader);
      return { tokenData, req };
    },
  });

  await server.start();
  server.applyMiddleware({ app, path: '/graphql' });

  app.listen(PORT, () => {
    console.log(`✅ Server running on port ${PORT}`);
    console.log(`GraphQL endpoint: http://localhost:${PORT}/graphql`);
    console.log(`APK download link: http://localhost:${PORT}/download/app.apk`);
    console.log(`Images directory: http://localhost:${PORT}/contents/images`);
  });
}

startServer();
