// models/PhoneNumber.js

const mongoose = require('mongoose');

const recordSchema = new mongoose.Schema({
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    default: null,
  },
  userName: String,   // 유저의 이름
  userType: String,   // 유저의 type (String으로 변경)
  name: String,       // 이 레코드(전화번호부)에서 저장한 이름
  type: Number,       // 레코드 자체의 타입(예: 99라면 위험)
  memo: String,       // 메모
  createdAt: { 
    type: Date, 
    default: Date.now,
    get: function(date) {
      return date ? date.toISOString() : null;
    }
  },
}, { timestamps: false });  // timestamps 비활성화

// 최상위 PhoneNumber 스키마
const phoneNumberSchema = new mongoose.Schema({
  phoneNumber: { type: String, required: true, unique: true },
  type: { type: Number, default: 0 },
  blockCount: { type: Number, default: 0 },  // 추가된 필드
  records: [recordSchema],
});

// **스키마 레벨에서 index 선언**
phoneNumberSchema.index({ 'records.userId': 1 });
phoneNumberSchema.index({ blockCount: 1 });  // blockCount에 대한 인덱스 추가

module.exports = mongoose.model('PhoneNumber', phoneNumberSchema);
