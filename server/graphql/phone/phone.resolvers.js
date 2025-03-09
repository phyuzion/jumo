// graphql/phone/phone.resolvers.js

const {
  UserInputError,
  AuthenticationError,
  ForbiddenError,
} = require('apollo-server-errors');
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

/**
 * 레코드 병합 로직
 *  - 기존 records[]: [{ userId, userName, userType, name, memo, type, createdAt }, ...]
 *  - 새로 들어온 newRecords[]: 같은 phoneNumber에 대한 여러 레코드
 *    (admin: userName,userType 직접 지정, 일반유저: userName=유저.name, userType=유저.type, userId=유저._id)
 *  - userId + userName + userType 를 사실상 "등록자 식별" 키로 삼고,
 *    기존 레코드를 찾아 업데이트, 없으면 push
 */
function mergeRecords(existingRecords, newRecords, isAdmin, user) {
  // 1) existingRecords => map by key: <userId> + '#' + <userName> + '#' + <userType>
  const map = {};
  for (const r of existingRecords) {
    const uid = r.userId ? String(r.userId) : '';
    const key = `${uid}#${r.userName||''}#${r.userType||0}`;
    map[key] = r;
  }

  // 2) newRecords => 병합
  for (const nr of newRecords) {
    // 최종 userId, userName, userType 결정
    let finalUserId = null;
    let finalUserName = '';
    let finalUserType = 0;

    if (isAdmin) {
      finalUserName = nr.userName?.trim() || 'Admin';
      finalUserType = nr.userType || 0;
      // admin 일 때는 userId 별도 지정이 없으면 null로 둠
    } else {
      finalUserId = user._id;
      finalUserName = user.name || '';
      finalUserType = user.type || 0;
    }

    const key = `${finalUserId || ''}#${finalUserName}#${finalUserType}`;
    let exist = map[key];

    if (!exist) {
      // 새 레코드
      exist = {
        userId: finalUserId,
        userName: finalUserName,
        userType: finalUserType,
        name: nr.name || '',
        memo: nr.memo || '',
        type: nr.type || 0,
        createdAt: nr.createdAt ? new Date(nr.createdAt) : new Date(),
      };
      map[key] = exist;
    } else {
      // 업데이트
      if (nr.name !== undefined) exist.name = nr.name;
      if (nr.memo !== undefined) exist.memo = nr.memo;
      if (nr.type !== undefined) exist.type = nr.type;
      exist.createdAt = nr.createdAt ? new Date(nr.createdAt) : new Date();
    }
  }

  // return merged array
  return Object.values(map);
}

module.exports = {
  Mutation: {
    /**
     * 한 번에 여러 phoneNumber 레코드 업서트 (BulkWrite 버전)
     *
     * records: [{ phoneNumber, userName?, userType?, name, memo, type, createdAt }, ...]
     *
     * 1) phoneNumber별로 grouping
     * 2) find({ phoneNumber: { $in: [...] } }) 한방에 기존 doc 로딩
     * 3) each phoneNumber => merge
     * 4) bulkWrite
     */
    upsertPhoneRecords: async (_, { records }, { tokenData }) => {
      const { isAdmin, user } = await checkUserOrAdmin(tokenData);

      if (!records || !Array.isArray(records) || records.length === 0) {
        throw new UserInputError('records 배열이 비어 있습니다.');
      }
      console.log('records arrived, count=', records.length);

      // 1) phoneNumber별로 그룹핑
      const mapByPhone = {};
      for (const rec of records) {
        const phone = rec.phoneNumber?.trim();
        if (!phone) continue;
        if (!mapByPhone[phone]) mapByPhone[phone] = [];
        mapByPhone[phone].push(rec);
      }
      const phoneNumbers = Object.keys(mapByPhone);
      if (phoneNumbers.length === 0) {
        return true; // 아무것도 없음
      }

      // 2) 기존 PhoneNumber docs 한 번에 로딩
      const existingDocs = await PhoneNumber.find({
        phoneNumber: { $in: phoneNumbers }
      }).lean(); // lean() -> plain object (optional)
      // phoneDocMap: { [phoneNumber]: { phoneNumber, type, records: [...]} }
      const phoneDocMap = {};
      for (const doc of existingDocs) {
        phoneDocMap[doc.phoneNumber] = doc;
      }

      // 최종 bulkOps
      const bulkOps = [];

      // 3) phoneNumber 별로 병합
      for (const phone of phoneNumbers) {
        const doc = phoneDocMap[phone];
        let currentRecords = [];
        let currentType = 0;
        if (doc) {
          currentRecords = doc.records || [];
          currentType = doc.type || 0;
        }

        // 병합
        const merged = mergeRecords(currentRecords, mapByPhone[phone], isAdmin, user);

        // 위험 번호 로직
        const countDanger = merged.filter(r => r.type === 99).length;
        let finalType = currentType;
        if (countDanger >= 3) {
          finalType = 99;
        }

        // 4) bulkOps: upsert
        bulkOps.push({
          updateOne: {
            filter: { phoneNumber: phone },
            update: {
              $set: {
                phoneNumber: phone,
                type: finalType,
                records: merged
              }
            },
            upsert: true
          }
        });
      }

      // 5) bulkWrite
      if (bulkOps.length > 0) {
        await PhoneNumber.bulkWrite(bulkOps);
      }

      console.log('bulkWrite done. ops=', bulkOps.length);
      return true;
    },
  },

  Query: {
    async getPhoneNumber(_, { phoneNumber }, { tokenData }) {
      if (!tokenData) throw new AuthenticationError('로그인이 필요합니다.');
      if (!phoneNumber || phoneNumber.trim() === '') {
        throw new UserInputError('phoneNumber가 비어 있습니다.');
      }
      return PhoneNumber.findOne({ phoneNumber });
    },

    async getPhoneNumbersByType(_, { type }, { tokenData }) {
      if (!tokenData) throw new AuthenticationError('로그인이 필요합니다.');
      return PhoneNumber.find({ type });
    },
  },
};
