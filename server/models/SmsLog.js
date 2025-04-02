const mongoose = require('mongoose');

const smsLogSchema = new mongoose.Schema({
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },
  phoneNumber: { type: String, required: true },
  time: { type: Date, required: true },
  content: { type: String, required: true },
  smsType: { type: String, required: true }  // "IN" or "OUT"
}, {
  timestamps: true
});

// 인덱스 설정
smsLogSchema.index({ userId: 1, time: -1 });  // 유저별 시간순 정렬
smsLogSchema.index({ phoneNumber: 1, time: -1 });  // 전화번호별 시간순 정렬

module.exports = mongoose.model('SmsLog', smsLogSchema); 