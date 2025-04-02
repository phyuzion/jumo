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
  createdAt: { type: Date, default: Date.now },
});

// 최상위 PhoneNumber 스키마
const phoneNumberSchema = new mongoose.Schema({
  phoneNumber: { type: String, required: true, unique: true },
  type: { type: Number, default: 0 },
  blockCount: { type: Number, default: 0 },  // 추가된 필드
  records: [recordSchema],
});

// 인덱스 설정 (unique: true는 스키마 정의에서 처리)
phoneNumberSchema.index({ 'records.userId': 1 });  // 레코드 조회용
phoneNumberSchema.index({ blockCount: 1 });  // 차단 수 필터링용
phoneNumberSchema.index({ type: 1 });  // 타입 필터링용
phoneNumberSchema.index({ 'records.createdAt': -1 });  // 레코드 정렬용

// 복합 인덱스 추가
phoneNumberSchema.index({ 'records.userId': 1, type: 1 });  // getMyRecords 최적화
phoneNumberSchema.index({ phoneNumber: 1, type: 1 });  // getPhoneNumber 최적화

module.exports = mongoose.model('PhoneNumber', phoneNumberSchema);
