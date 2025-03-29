const TodayRecord = require('../../models/TodayRecord');
const { toKstISOString } = require('../../utils/date');

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
        createdAt: toKstISOString(record.createdAt), // UTC -> KST
        updatedAt: toKstISOString(record.updatedAt), // UTC -> KST
      }));
    },
  },
};

module.exports = resolvers; 