const TodayRecord = require('../../models/TodayRecord');

const resolvers = {
  Query: {
    getTodayRecord: async (_, { phoneNumber }) => {
      const records = await TodayRecord.find({ phoneNumber })
        .sort({ time: -1 });
      
      return records.map(record => ({
        id: record._id,
        phoneNumber: record.phoneNumber,
        userName: record.userName,
        userType: record.userType,
        callType: record.callType,
        time: record.time,
      }));
    },
  },
};

module.exports = resolvers; 