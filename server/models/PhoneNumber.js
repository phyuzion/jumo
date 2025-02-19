// models/PhoneNumber.js

const mongoose = require('mongoose');

// 전화번호별로 여러 기록을 쌓기 위한 Record 스키마
const recordSchema = new mongoose.Schema({
  userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
  name: String,
  memo: String,
  createdAt: { type: Date, default: Date.now },
});

// 최상위 PhoneNumber 스키마
const phoneNumberSchema = new mongoose.Schema({
  phoneNumber: { type: String, required: true, unique: true },
  type: { type: Number, default: 0 },
  records: [recordSchema],
});

module.exports = mongoose.model('PhoneNumber', phoneNumberSchema);
