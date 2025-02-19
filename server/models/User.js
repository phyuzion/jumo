// models/User.js

const mongoose = require('mongoose');

const userSchema = new mongoose.Schema({
  systemId: { type: String, required: true, unique: true },
  loginId: { type: String, required: true, unique: true },
  password: { type: String, required: true }, // bcrypt 해시
  name: { type: String },
  phoneNumber: { type: String },
  type: { type: Number, default: 0 },
  createdAt: { type: Date, default: Date.now },
  validUntil: { type: Date },                  // 유효 기간
  refreshToken: { type: String, default: '' }, // 리프레시 토큰
});

module.exports = mongoose.model('User', userSchema);
