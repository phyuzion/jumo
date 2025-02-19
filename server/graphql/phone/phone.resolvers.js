// graphql/phone/phone.resolvers.js

const { UserInputError, AuthenticationError, ForbiddenError } = require('apollo-server-errors');
const PhoneNumber = require('../../models/PhoneNumber');
const User = require('../../models/User');

async function checkUserValid(tokenData) {
  if (!tokenData?.userId) {
    throw new AuthenticationError('로그인이 필요합니다.');
  }
  const user = await User.findById(tokenData.userId);
  if (!user) {
    throw new ForbiddenError('유효하지 않은 유저입니다.');
  }
  if (user.validUntil && user.validUntil < new Date()) {
    throw new ForbiddenError('유효 기간이 만료된 계정입니다.');
  }
  return user;
}

module.exports = {
  Query: {
    getPhoneNumber: async (_, { phoneNumber }, { tokenData }) => {
      if (!tokenData) throw new AuthenticationError('로그인이 필요합니다.');
      if (!phoneNumber || phoneNumber.trim() === '') {
        throw new UserInputError('phoneNumber가 비어 있습니다.');
      }
      return PhoneNumber.findOne({ phoneNumber });
    },

    getPhoneNumbersByType: async (_, { type }, { tokenData }) => {
      if (!tokenData) throw new AuthenticationError('로그인이 필요합니다.');
      return PhoneNumber.find({ type });
    },
  },

  Mutation: {
    uploadPhoneRecords: async (_, { records }, { tokenData }) => {
      const user = await checkUserValid(tokenData);

      if (!records || !Array.isArray(records) || records.length === 0) {
        throw new UserInputError('records 배열이 비어 있습니다.');
      }

      for (const record of records) {
        const { phoneNumber, name, memo } = record;
        if (!phoneNumber || phoneNumber.trim() === '') {
          continue;
        }

        let phoneDoc = await PhoneNumber.findOne({ phoneNumber });
        if (!phoneDoc) {
          phoneDoc = new PhoneNumber({ phoneNumber, type: 0, records: [] });
        }

        const existingRecord = phoneDoc.records.find(
          (r) => r.userId.toString() === user._id.toString()
        );

        if (existingRecord) {
          const isSameName = existingRecord.name === (name || '');
          const isSameMemo = existingRecord.memo === (memo || '');
          if (!isSameName || !isSameMemo) {
            existingRecord.name = name || '';
            existingRecord.memo = memo || '';
            existingRecord.createdAt = new Date();
          }
        } else {
          phoneDoc.records.push({
            userId: user._id,
            name: name || '',
            memo: memo || '',
            createdAt: new Date(),
          });
        }
        await phoneDoc.save();
      }

      return true;
    },

    updatePhoneRecordMemo: async (_, { phoneNumber, memo }, { tokenData }) => {
      const user = await checkUserValid(tokenData);

      if (!phoneNumber || phoneNumber.trim() === '') {
        throw new UserInputError('phoneNumber가 비어 있습니다.');
      }

      const phoneDoc = await PhoneNumber.findOne({ phoneNumber });
      if (!phoneDoc) {
        throw new UserInputError('해당 전화번호가 존재하지 않습니다.');
      }

      let foundRecord = phoneDoc.records.find(
        (r) => r.userId.toString() === user._id.toString()
      );

      if (!foundRecord) {
        throw new ForbiddenError('본인이 업로드한 기록이 없습니다.');
      }

      if (foundRecord.memo === memo) {
        // 동일 메모면 그냥 true
        return true;
      }

      foundRecord.memo = memo;
      foundRecord.createdAt = new Date();
      await phoneDoc.save();

      return true;
    },
  },
};
