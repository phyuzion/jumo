// config/db.js
const mongoose = require('mongoose');
require('dotenv').config();

const connectDB = async () => {
  try {
    await mongoose.connect(process.env.MONGODB_URI, {
      dbName: 'jumo'
    });
    console.log('✅ MongoDB connected');

    // MongoDB 쿼리 로깅 활성화
    mongoose.set('debug', true);
    console.log('✅ MongoDB query logging enabled');
  } catch (err) {
    console.error('❌ MongoDB connection error:', err);
    process.exit(1);
  }
};

module.exports = connectDB;
