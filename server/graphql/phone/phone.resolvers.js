// graphql/phone/phone.resolvers.js

const { UserInputError, AuthenticationError, ForbiddenError } = require('apollo-server-errors');
const PhoneNumber = require('../../models/PhoneNumber');
const User = require('../../models/User');

/**
 * 유저 검증 (로그인 + validUntil)
 */
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
    // 업서트 Mutation
    upsertPhoneRecords: async (_, { records }, { tokenData }) => {
      const user = await checkUserValid(tokenData);

      if (!records || !Array.isArray(records) || records.length === 0) {
        throw new UserInputError('records 배열이 비어 있습니다.');
      }

      for (const record of records) {
        const { phoneNumber, name, memo, type } = record;

        // phoneNumber 필수 체크
        if (!phoneNumber || phoneNumber.trim() === '') {
          continue; // 혹은 throw new UserInputError('phoneNumber가 없습니다.');
        }

        // 1) PhoneNumber 문서 찾거나 생성
        let phoneDoc = await PhoneNumber.findOne({ phoneNumber });
        if (!phoneDoc) {
          phoneDoc = new PhoneNumber({
            phoneNumber,
            type: 0, // 기본 값 (위험번호 아님)
            records: [],
          });
        }

        // 2) userId 기반으로 record 찾기
        let userRecord = phoneDoc.records.find(
          (r) => r.userId.toString() === user._id.toString()
        );

        // 없으면 새로 push
        if (!userRecord) {
          userRecord = {
            userId: user._id,
            name: name || '',
            memo: memo || '',
            createdAt: new Date(),
            type: type || 0,
          };
          phoneDoc.records.push(userRecord);

        } else {
          // 있으면 업데이트
          if (name !== undefined) userRecord.name = name;
          if (memo !== undefined) userRecord.memo = memo;
          if (type !== undefined) userRecord.type = type;
          userRecord.createdAt = new Date();
        }

        // 예) 위험 번호 로직
        // "type=99"인 record가 3개 이상이면 phoneDoc.type=99
        const countDanger = phoneDoc.records.filter((rec) => rec.type === 99).length;
        if (countDanger >= 3) {
          phoneDoc.type = 99; // 위험 번호로 설정
        }

        await phoneDoc.save();
      }

      return true;
    },
  },
};
