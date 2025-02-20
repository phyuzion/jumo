// graphql/phone/phone.resolvers.js

const { UserInputError, AuthenticationError, ForbiddenError } = require('apollo-server-errors');
const PhoneNumber = require('../../models/PhoneNumber');
const User = require('../../models/User');

async function checkUserOrAdmin(tokenData) {
  // 반환: { isAdmin: boolean, user: User doc or null }
  if (tokenData?.adminId) {
    return { isAdmin: true, user: null };
  } else if (tokenData?.userId) {
    const user = await User.findById(tokenData.userId);
    if (!user) throw new ForbiddenError('유효하지 않은 유저입니다.');
    if (user.validUntil && user.validUntil < new Date()) {
      throw new ForbiddenError('유효 기간이 만료된 계정입니다.');
    }
    return { isAdmin: false, user };
  } else {
    throw new AuthenticationError('로그인이 필요합니다.');
  }
}

module.exports = {
  Mutation: {
    upsertPhoneRecords: async (_, { records }, { tokenData }) => {
      const { isAdmin, user } = await checkUserOrAdmin(tokenData);

      if (!records || !Array.isArray(records) || records.length === 0) {
        throw new UserInputError('records 배열이 비어 있습니다.');
      }

      for (const record of records) {
        // record = { phoneNumber, userName?, userType?, name, memo, type }

        const { phoneNumber } = record;
        if (!phoneNumber || phoneNumber.trim() === '') {
          continue; // or throw error
        }

        // 1) phoneNumber doc 찾거나 생성
        let phoneDoc = await PhoneNumber.findOne({ phoneNumber });
        if (!phoneDoc) {
          phoneDoc = new PhoneNumber({
            phoneNumber,
            type: 0,
            records: [],
          });
        }

        // 2) 실제로 레코드에 저장할 userName, userType
        let finalUserName = '';
        let finalUserType = 0;

        if (isAdmin) {
          // 어드민이라면 인풋에 들어온 userName, userType 우선 사용
          finalUserName = record.userName ?? '';
          finalUserType = record.userType ?? 0;
        } else {
          // 일반 유저 => 로그인 정보로 대체
          finalUserName = user.name || '';
          finalUserType = user.type || 0;
        }

        // 3) 기존 레코드 찾기 (userName + userType 둘 다 매칭?)
        let existingRecord = phoneDoc.records.find(
          (r) => r.userName === finalUserName && r.userType === finalUserType
        );

        if (!existingRecord) {
          // 새로 추가
          phoneDoc.records.push({
            userName: finalUserName,
            userType: finalUserType,
            name: record.name || '',
            memo: record.memo || '',
            type: record.type || 0,
            createdAt: record.createdAt ? new Date(record.createdAt) : new Date(),
          });
        } else {
          // 업데이트
          if (record.name !== undefined)  existingRecord.name = record.name;
          if (record.memo !== undefined)  existingRecord.memo = record.memo;
          if (record.type !== undefined)  existingRecord.type = record.type;
          existing.createdAt = record.createdAt ? new Date(record.createdAt) : new Date();
        }

        // 4) 위험 번호 로직
        const countDanger = phoneDoc.records.filter((r) => r.type === 99).length;
        if (countDanger >= 3) {
          phoneDoc.type = 99;
        }

        await phoneDoc.save();
      }

      return true;
    },
  },

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
};
