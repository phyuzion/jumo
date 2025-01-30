// models/Admin.js
const mongoose = require('mongoose');

const adminSchema = new mongoose.Schema({
  adminId: { type: String, required: true, unique: true },
  password: { type: String, required: true },
  createdAt: { type: Date, default: Date.now },
});

// 예: 비밀번호 해시를 위해 pre('save') 훅을 사용할 수도 있음

module.exports = mongoose.model('Admin', adminSchema);
