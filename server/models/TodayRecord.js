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
    callType: {
      type: String,
      required: true,
    },
    time: {
      type: Date,
      required: true,
    }
  }
);

// phoneNumber와 userName에 대한 복합 인덱스 추가
todayRecordSchema.index({ phoneNumber: 1, userName: 1 }, { unique: true });
// TTL 인덱스 추가 (24시간 후 자동 삭제)
todayRecordSchema.index({ time: 1 }, { expireAfterSeconds: 86400 });

const TodayRecord = mongoose.model('TodayRecord', todayRecordSchema);

module.exports = TodayRecord; 