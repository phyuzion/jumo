const TodayRecord = require('../../models/TodayRecord');

const resolvers = {
  Query: {
    getTodayRecord: async (_, { phoneNumber }) => {
      const records = await TodayRecord.find({ phoneNumber })
        .sort({ createdAt: -1 });
      
      return records.map(record => ({
        id: record._id,
        phoneNumber: record.phoneNumber,
        userName: record.userName,
        userType: record.userType,
        callType: record.callType,
        createdAt: record.createdAt, // Date 스칼라 타입이 자동 변환
        updatedAt: record.updatedAt, // Date 스칼라 타입이 자동 변환
      }));
    },
  },
};

module.exports = resolvers; 