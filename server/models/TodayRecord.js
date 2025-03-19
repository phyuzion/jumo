const mongoose = require('mongoose');

const todayRecordSchema = new mongoose.Schema(
  {
    phoneNumber: {
      type: String,
      required: true,
      index: true,
    },
    userName: {
      type: String,
      required: true,
    },
    userType: {
      type: Number,
      required: true,
    },
    createdAt: {
      type: Date,
      required: true,
      index: true,
    },
  },
  {
    timestamps: true,
  }
);

// 24시간이 지난 레코드는 자동으로 삭제되도록 TTL 인덱스 추가
todayRecordSchema.index({ createdAt: 1 }, { expireAfterSeconds: 24 * 60 * 60 });

module.exports = mongoose.model('TodayRecord', todayRecordSchema); 