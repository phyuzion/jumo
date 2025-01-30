// config/db.js
const mongoose = require('mongoose');
require('dotenv').config(); // 환경변수 로드

const connectDB = async () => {
  try {
    await mongoose.connect(process.env.MONGODB_URI, {
      useNewUrlParser: true,
      useUnifiedTopology: true,
      // useCreateIndex, useFindAndModify 등 mongoose 6버전 이후는 자동
    });
    console.log('MongoDB Connected');
  } catch (err) {
    console.error(err);
    process.exit(1);
  }
};

module.exports = connectDB;
