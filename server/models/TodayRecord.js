const mongoose = require('mongoose');

const todayRecordSchema = new mongoose.Schema(
  {
    phoneNumber: {
      type: String,
      required: true,
    },
    userName: {
      type: String,
      required: true,
    },
    userType: {
      type: Number,
      required: true,
    },
    callType: {
      type: String,
      required: true,
    },
    createdAt: {
      type: Date,
      default: Date.now,
      expires: 86400, // 24시간 후 자동 삭제
    },
  },
  {
    timestamps: true,
  }
);

// phoneNumber와 userName에 대한 복합 인덱스 추가
todayRecordSchema.index({ phoneNumber: 1, userName: 1 }, { unique: true });

const TodayRecord = mongoose.model('TodayRecord', todayRecordSchema);

module.exports = TodayRecord; 