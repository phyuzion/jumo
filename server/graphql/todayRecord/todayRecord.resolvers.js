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
        interactionType: record.interactionType,
        createdAt: record.createdAt.toISOString(),
      }));
    },
  },
};

module.exports = resolvers; 