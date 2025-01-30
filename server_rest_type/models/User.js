// models/User.js
const mongoose = require('mongoose');

const userSchema = new mongoose.Schema({
  userId: { type: String, required: true, unique: true }, // 6글자 자동생성
  phone: { type: String, required: true },
  name: { type: String },
  memo: { type: String, default: '' },
  validUntil: { type: Date }, // 1달 유효
  createdAt: { type: Date, default: Date.now },
});

module.exports = mongoose.model('User', userSchema);
