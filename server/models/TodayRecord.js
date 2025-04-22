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
      type: String,
      required: true,
    },
    interactionType: {
      type: String,
      required: true,
      enum: ['CALL', 'SMS']
    },
    createdAt: {
      type: Date,
      required: true,
      expires: 86400, // 24시간 후 자동 삭제
    },
  },
  {
    timestamps: false
  }
);

// phoneNumber와 userName에 대한 복합 인덱스 추가
todayRecordSchema.index({ phoneNumber: 1, userName: 1, interactionType: 1 }, { unique: true });
todayRecordSchema.index({ createdAt: -1 });

const TodayRecord = mongoose.model('TodayRecord', todayRecordSchema);

module.exports = TodayRecord; 