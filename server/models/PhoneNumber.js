// models/PhoneNumber.js

const mongoose = require('mongoose');

const recordSchema = new mongoose.Schema({
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    default: null,
  },
  userName: String,   // 유저의 이름
  userType: Number,   // 유저의 type
  name: String,       // 이 레코드(전화번호부)에서 저장한 이름
  type: Number,       // 레코드 자체의 타입(예: 99라면 위험)
  memo: String,       // 메모
  createdAt: { type: Date, default: Date.now },
});

// 최상위 PhoneNumber 스키마
const phoneNumberSchema = new mongoose.Schema({
  phoneNumber: { type: String, required: true, unique: true },
  type: { type: Number, default: 0 },
  records: [recordSchema],
});

// **스키마 레벨에서 index 선언**
phoneNumberSchema.index({ 'records.userId': 1 });

module.exports = mongoose.model('PhoneNumber', phoneNumberSchema);
