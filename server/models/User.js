// models/User.js

const mongoose = require('mongoose');

const userSchema = new mongoose.Schema({
  loginId: { type: String, required: true, unique: true },
  password: { type: String, required: true }, // bcrypt 해시
  name: { type: String },
  phoneNumber: { type: String },
  type: { type: Number, default: 0 },
  createdAt: { type: Date, default: Date.now },
  validUntil: { type: Date }, 
  refreshToken: { type: String, default: '' },

  // 새 필드 추가
  region: { type: String, default: '' },    // 지역
  grade: { type: String, default: '' },     // 등급
  searchCount: { type: Number, default: 0 }, // 검색 횟수
  lastSearchTime: { type: Date },           // 마지막 검색 시간
  settings: { type: String, default: '' },  // 설정(문자열로 저장)
  blockList: [String],      // 차단된 전화번호 목록

  // 통화내역 (최신이 위, 최대 200)
  callLogs: [
    {
      phoneNumber: String,
      time: Date,
      callType: String, // "IN" or "OUT"
    },
  ],

  // 문자내역 (최신이 위, 최대 200)
  smsLogs: [
    {
      phoneNumber: String,
      time: Date,
      content: String,
      smsType: String, // "IN" or "OUT"
    },
  ],
});

module.exports = mongoose.model('User', userSchema);
