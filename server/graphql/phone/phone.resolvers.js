// graphql/phone/phone.resolvers.js

const {
  UserInputError,
  AuthenticationError,
  ForbiddenError,
} = require('apollo-server-errors');
const PhoneNumber = require('../../models/PhoneNumber');
const User = require('../../models/User');
const Grade = require('../../models/Grade');
const { withTransaction } = require('../../utils/transaction');

const { checkUserOrAdmin } = require('../auth/utils');

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
    const key = `${uid}#${r.userName||''}#${r.userType||'일반'}`;
    map[key] = r;
  }

  // 2) newRecords => 병합
  for (const nr of newRecords) {
    // 최종 userId, userName, userType 결정
    let finalUserId = null;
    let finalUserName = '';
    let finalUserType = '일반';

    if (isAdmin) {
      finalUserName = nr.userName?.trim() || 'Admin';
      finalUserType = nr.userType || '일반';
      // admin 일 때는 userId 별도 지정이 없으면 null로 둠
    } else {
      finalUserId = user._id;
      finalUserName = user.name || '';
      finalUserType = user.userType || '일반';
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
      // 1) 권한 체크
      const { isAdmin, user } = await checkUserOrAdmin(tokenData);

      if (!records || !Array.isArray(records) || records.length === 0) {
        throw new UserInputError('records 배열이 비어 있습니다.');
      }
      console.log('records arrived, count=', records.length);

      // 2) User의 phoneRecords 업데이트
      let userRecordsCount = 0;
      console.log('starting user.phoneRecords update...');
      for (const rec of records) {
        const phone = rec.phoneNumber?.trim();
        if (!phone) {
          console.log('skipping empty phone number');
          continue;
        }

        const newRecord = {
          phoneNumber: phone,
          name: rec.name || '',
          type: rec.type || 0,
          memo: rec.memo || '',
          createdAt: rec.createdAt ? new Date(rec.createdAt) : new Date()
        };

        // 중복 체크 후 추가
        const existingIndex = user.phoneRecords.findIndex(
          r => r.phoneNumber === phone
        );

        if (existingIndex >= 0) {
          // 기존 레코드 업데이트
          user.phoneRecords[existingIndex] = newRecord;
          userRecordsCount++;
        } else {
          // 새 레코드 추가
          user.phoneRecords.unshift(newRecord);
          userRecordsCount++;
        }
      }
      console.log('user.phoneRecords update completed, count=', userRecordsCount);

      // 3) User 저장
      console.log('starting user save...');
      await withTransaction(async (session) => {
        await user.save({ session });
      });
      console.log('user save completed');

      // 1) phoneNumber별로 그룹핑
      console.log('starting phone number grouping...');
      const mapByPhone = {};
      for (const rec of records) {
        const phone = rec.phoneNumber?.trim();
        if (!phone) continue;
        if (!mapByPhone[phone]) mapByPhone[phone] = [];
        mapByPhone[phone].push(rec);
      }
      const phoneNumbers = Object.keys(mapByPhone);
      if (phoneNumbers.length === 0) {
        console.log('no valid phone numbers to process');
        return true; // 아무것도 없음
      }
      console.log('phoneNumbers to update, count=', phoneNumbers.length);

      // 2) 기존 PhoneNumber docs 한 번에 로딩
      const existingDocs = await PhoneNumber.find({
        phoneNumber: { $in: phoneNumbers }
      }).lean();

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
        let currentBlockCount = 0;
        if (doc) {
          currentRecords = doc.records || [];
          currentType = doc.type || 0;
          currentBlockCount = doc.blockCount || 0;
        }

        // 병합
        const merged = mergeRecords(currentRecords, mapByPhone[phone], isAdmin, user);

        // 위험 번호 로직
        const countDanger = merged.filter(r => r.type === 99).length;
        let finalType = currentType;
        if (countDanger >= 3) {
          finalType = 99;
        }

        // blockCount 계산
        let blockCount = currentBlockCount;
        for (const record of merged) {
          const name = record.name?.toLowerCase() || '';
          if (name.includes('ㅋㅍ') || name.includes('콜폭')) {
            blockCount++;
          }
        }

        // 4) bulkOps: upsert
        bulkOps.push({
          updateOne: {
            filter: { phoneNumber: phone },
            update: {
              $set: {
                phoneNumber: phone,
                type: finalType,
                blockCount: blockCount,
                records: merged
              }
            },
            upsert: true
          }
        });
      }

      // 5) bulkWrite
      if (bulkOps.length > 0) {
        await withTransaction(async (session) => {
          await PhoneNumber.bulkWrite(bulkOps, { session });
        });
      }

      console.log('bulkWrite done. ops=', bulkOps.length);
      return true;
    },
  },

  Query: {
    async getPhoneNumber(_, { phoneNumber, isRequested }, { tokenData }) {
      if (!tokenData) throw new AuthenticationError('로그인이 필요합니다.');
      if (!phoneNumber || phoneNumber.trim() === '') {
        throw new UserInputError('phoneNumber가 비어 있습니다.');
      }

      // 유저이고 isRequested가 true일 때만 검색 횟수 체크
      if (isRequested && tokenData.userId) {
        const user = await User.findById(tokenData.userId);
        if (!user) {
          throw new UserInputError('유저를 찾을 수 없습니다.');
        }

        // 오늘 날짜의 시작 시간 (00:00:00)
        const today = new Date();
        today.setHours(0, 0, 0, 0);
        console.log('today=', today);
        console.log('user.lastSearchTime=', user.lastSearchTime);

        // 마지막 검색 시간이 오늘이 아니면 카운트 리셋
        if (!user.lastSearchTime || user.lastSearchTime < today) {
          user.searchCount = 0;
        }

        // grade에 해당하는 limit 값 가져오기
        const grade = await Grade.findOne({ name: user.grade });
        if (!grade) {
          throw new UserInputError('유효하지 않은 등급입니다.');
        }

        // limit 값보다 크면 에러
        if (user.searchCount >= grade.limit) {
          throw new ForbiddenError('오늘의 검색 제한을 초과했습니다. 내일 다시 시도해주세요.');
        }

        // 검색 횟수 증가 및 시간 업데이트
        user.searchCount += 1;
        user.lastSearchTime = new Date();
        await user.save();
      }

      return PhoneNumber.findOne({ phoneNumber });
    },

    async getPhoneNumbersByType(_, { type }, { tokenData }) {
      if (!tokenData) throw new AuthenticationError('로그인이 필요합니다.');
      return PhoneNumber.find({ type });
    },

    getMyRecords: async (_, __, { tokenData }) => {
      const { isAdmin, user } = await checkUserOrAdmin(tokenData);
      if (!user) {
        throw new AuthenticationError('로그인이 필요합니다.');
      }

      // User 모델의 phoneRecords를 그대로 반환
      return user.phoneRecords;
    },
    
    getBlockNumbers: async (_, { count }, { tokenData }) => {
      if (!tokenData) throw new AuthenticationError('로그인이 필요합니다.');
      return PhoneNumber.find(
        { blockCount: { $gte: count } },
        { phoneNumber: 1, blockCount: 1, _id: 0 }  // 필요한 필드만 선택
      );
    },
  },
};
