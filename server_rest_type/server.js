// server.js
require('dotenv').config();
const express = require('express');
const cors = require('cors');
const connectDB = require('./config/db');
const routes = require('./routes');

const app = express();

// DB 연결
connectDB();

// 미들웨어
app.use(cors());
app.use(express.json());

// 라우트
app.use('/api', routes);

// 포트 세팅
const PORT = process.env.PORT || 4000;
app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});
