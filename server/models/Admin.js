// models/Admin.js

const mongoose = require('mongoose');
const adminSchema = new mongoose.Schema({
  username: { type: String, required: true, unique: true },
  password: { type: String, required: true }, // bcrypt 해시된 패스워드
  refreshToken: { type: String, default: '' }, // 리프레시 토큰 보관 (선택)
});

module.exports = mongoose.model('Admin', adminSchema);
