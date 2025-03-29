// config/db.js
const mongoose = require('mongoose');
const datePlugin = require('../utils/datePlugin');
require('dotenv').config();

// 글로벌 플러그인 등록 - 모든 스키마에 Date 처리 적용
mongoose.plugin(datePlugin);

const connectDB = async () => {
  try {
    await mongoose.connect(process.env.MONGODB_URI, {
      useNewUrlParser: true,
      useUnifiedTopology: true,
    });
    
    console.log('✅ MongoDB connected');
  } catch (err) {
    console.error('❌ MongoDB connection error:', err.message);
    process.exit(1);
  }
};

module.exports = connectDB;
