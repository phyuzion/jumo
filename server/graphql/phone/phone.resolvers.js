// graphql/phone/phone.resolvers.js

const {
  UserInputError,
  AuthenticationError,
  ForbiddenError,
} = require('apollo-server-errors');
const PhoneNumber = require('../../models/PhoneNumber');
const User = require('../../models/User');
const Grade = require('../../models/Grade');
const TodayRecord = require('../../models/TodayRecord');
const { withTransaction } = require('../../utils/transaction');

const { checkUserOrAdmin } = require('../auth/utils');

/**
 * 레코드 병합 로직
 *  - 기존 records[]: [{ userId, userName, userType, name, memo, type, createdAt }, ...]
 *  - 새로 들어온 newRecords[]: 같은 phoneNumber에 대한 여러 레코드
 *    (admin: userName,userType 직접 지정, 일반유저: userName=유저.name, userType=유저.type, userId=유저._id)
 */
function mergeRecords(existingRecords, newRecords, isAdmin, user) {
  // 1) 기존 레코드는 그대로 유지
  let resultRecords = [...existingRecords];

  // 2) 새 레코드 처리
  for (const nr of newRecords) {
    let finalUserId = isAdmin ? nr.userId : user._id;
    let finalUserName = isAdmin ? (nr.userName?.trim() || 'Admin') : (user.name || '');
    let finalUserType = isAdmin ? (nr.userType || '일반') : (user.userType || '일반');

    // 기존 레코드 중 매칭되는 것 찾기
    let existingIndex = -1;
    if (isAdmin) {
      // 어드민은 phoneNumber와 userName으로 매칭
      existingIndex = resultRecords.findIndex(r => 
        r.phoneNumber === nr.phoneNumber && r.userName === finalUserName
      );
    } else {
      // 일반 유저는 자신의 userId와 phoneNumber로 매칭
      existingIndex = resultRecords.findIndex(r => 
        r.userId && String(r.userId) === String(finalUserId) && 
        r.phoneNumber === nr.phoneNumber
      );
    }

    if (existingIndex >= 0) {
      // 기존 레코드 업데이트
      let exist = resultRecords[existingIndex];
      if (isAdmin) {
        if (nr.name !== undefined) exist.name = nr.name;
        if (nr.memo !== undefined) exist.memo = nr.memo;
        if (nr.type !== undefined) exist.type = nr.type;
        if (nr.userType !== undefined) exist.userType = nr.userType;
        if (nr.userName !== undefined) exist.userName = nr.userName;
      } else {
        if (nr.name !== undefined) exist.name = nr.name;
        if (nr.memo !== undefined) exist.memo = nr.memo;
        if (nr.type !== undefined) exist.type = nr.type;
      }
      // createdAt 업데이트
      if (nr.createdAt) {
        exist.createdAt = new Date(nr.createdAt);
      }
    } else {
      // 새 레코드 추가
      resultRecords.push({
        userId: finalUserId,
        userName: finalUserName,
        userType: finalUserType,
        phoneNumber: nr.phoneNumber,
        name: nr.name || '',
        memo: nr.memo || '',
        type: nr.type || 0,
        createdAt: nr.createdAt ? new Date(nr.createdAt) : new Date()
      });
    }
  }

  return resultRecords;
}

// 외부 테스트용으로 mergeRecords 함수 별도 내보내기
// GraphQL resolver가 아닌 다른 모듈에서 사용 가능하게 함
exports.testUtils = {
  mergeRecords
};

// GraphQL resolver는 객체 형태여야 함
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
      console.log('[Phone.Resolvers] upsertPhoneRecords received, count=', records.length);

      const mapByPhone = {};
      for (const rec of records) {
        // name 필드 필수 체크 (스키마에서 이미 처리)
        // if (!rec.name || typeof rec.name !== 'string' || rec.name.trim() === '') continue;
        const phone = rec.phoneNumber?.trim();
        if (!phone) continue;
        if (!mapByPhone[phone]) mapByPhone[phone] = [];
        // createdAt은 String으로 받음 (mergeRecords에서 Date로 변환)
        mapByPhone[phone].push(rec);
      }
      
      const phoneNumbers = Object.keys(mapByPhone);
      if (phoneNumbers.length === 0) {
        return true;
      }

      const existingDocs = await PhoneNumber.find(
        { phoneNumber: { $in: phoneNumbers } }
      ).lean();

      const phoneDocMap = {};
      for (const doc of existingDocs) {
        phoneDocMap[doc.phoneNumber] = doc;
      }

      const bulkOps = [];

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

        // 병합 (mergeRecords는 name, memo, type 업데이트)
        const merged = mergeRecords(currentRecords, mapByPhone[phone], isAdmin, user);

        // 위험 번호 로직 유지
        const countDanger = merged.filter(r => r.type === 99).length;
        let finalType = currentType;
        if (countDanger >= 3) {
          finalType = 99;
        }

        // blockCount 계산 로직 유지
        let blockCount = currentBlockCount;
        for (const record of merged) {
          const name = record.name?.toLowerCase() || '';
          if (name.includes('ㅋㅍ') || name.includes('콜폭')) {
            blockCount++;
          }
        }

        bulkOps.push({
          updateOne: {
            filter: { phoneNumber: phone },
            update: {
              $set: {
                phoneNumber: phone,
                type: finalType,
                blockCount: blockCount,
                records: merged // 병합된 레코드 배열 전체 저장
              }
            },
            upsert: true
          }
        });
      }

      if (bulkOps.length > 0) {
        await withTransaction(async (session) => {
          await PhoneNumber.bulkWrite(bulkOps, { session });
        });
      }

      console.log('[Phone.Resolvers] upsertPhoneRecords bulkWrite 완료. ops=', bulkOps.length);
      return true;
    },
  },

  Query: {
    async getPhoneNumber(_, { phoneNumber, isRequested }, { tokenData }) {
      if (!tokenData) throw new AuthenticationError('로그인이 필요합니다.');
      const normalizedPhoneNumber = phoneNumber?.trim();
      if (!normalizedPhoneNumber) {
        throw new UserInputError('phoneNumber가 비어 있습니다.');
      }

      // --- 검색 횟수 체크 로직 (KST 기준) ---
      if (isRequested && tokenData.userId) {
        const user = await User.findById(tokenData.userId).select('searchCount lastSearchTime grade');
        if (!user) {
          throw new UserInputError('유저를 찾을 수 없습니다.');
        }

        // KST 기준으로 오늘 날짜 계산 (UTC+9)
        const now = new Date();
        const kstToday = new Date(now.getTime() + (9 * 60 * 60 * 1000));
        kstToday.setHours(0, 0, 0, 0);
        
        // lastSearchTime을 KST로 변환하여 비교
        const lastSearchKST = user.lastSearchTime ? 
          new Date(user.lastSearchTime.getTime() + (9 * 60 * 60 * 1000)) : 
          null;

        if (!lastSearchKST || lastSearchKST < kstToday) {
          user.searchCount = 0;
        }

        const grade = await Grade.findOne({ name: user.grade });
        if (!grade) {
          throw new UserInputError('유효하지 않은 등급입니다.');
        }
        if (user.searchCount >= grade.limit) {
          throw new ForbiddenError('오늘의 검색 제한을 초과했습니다. 내일 다시 시도해주세요.');
        }
        user.searchCount += 1;
        user.lastSearchTime = new Date(); // UTC로 저장
        await user.save();
      }
      // --- 검색 횟수 체크 로직 끝 ---

      const [registeredUser, phoneDoc, todayDocs] = await Promise.all([
        User.findOne({ phoneNumber: normalizedPhoneNumber }).lean(),
        PhoneNumber.findOne({ phoneNumber: normalizedPhoneNumber }).lean(),
        TodayRecord.find({ phoneNumber: normalizedPhoneNumber }).sort({ createdAt: -1 }).lean(),
      ]);

      // TodayRecord 포맷팅 (항상 수행)
      const formattedTodayRecords = todayDocs.map(record => ({
        id: record._id.toString(),
        phoneNumber: record.phoneNumber,
        userName: record.userName,
        userType: record.userType,
        interactionType: record.interactionType,
        createdAt: record.createdAt.toISOString(),
      }));

      if (registeredUser) {
        // 사용자를 찾은 경우
        return {
          id: phoneDoc?._id?.toString() ?? registeredUser._id.toString(), // phoneDoc 없으면 User ID 사용
          phoneNumber: normalizedPhoneNumber,
          type: phoneDoc?.type ?? 0, // phoneDoc 없으면 기본값
          blockCount: phoneDoc?.blockCount ?? 0, // phoneDoc 없으면 기본값
          records: (phoneDoc?.records || []).map(r => ({
            ...r,
            createdAt: r.createdAt?.toISOString()
          })),
          todayRecords: formattedTodayRecords,
          isRegisteredUser: true,
          registeredUserInfo: {
            userName: registeredUser.name || '',
            userRegion: registeredUser.region,
            userType: registeredUser.userType || '일반',
          },
        };
      } else {
        // 사용자를 찾지 못한 경우
        if (!phoneDoc) {
          // PhoneNumber 정보도 없으면
          return {
            id: normalizedPhoneNumber, // 임시 ID
            phoneNumber: normalizedPhoneNumber,
            type: 0,
            blockCount: 0,
            records: [],
            todayRecords: formattedTodayRecords,
            isRegisteredUser: false,
            registeredUserInfo: null,
          };
        }
        // PhoneNumber 정보는 있는 경우
        return {
          ...phoneDoc,
          id: phoneDoc._id.toString(),
          records: phoneDoc.records.map(r => ({
            ...r,
            createdAt: r.createdAt?.toISOString()
          })),
          todayRecords: formattedTodayRecords,
          isRegisteredUser: false,
          registeredUserInfo: null,
        };
      }
    },

    async getPhoneNumbersByType(_, { type }, { tokenData }) {
      if (!tokenData) throw new AuthenticationError('로그인이 필요합니다.');
      return PhoneNumber.find({ type });
    },

    getBlockNumbers: async (_, { count }, { tokenData }) => {
      if (!tokenData) throw new AuthenticationError('로그인이 필요합니다.');
      return PhoneNumber.find(
        { blockCount: { $gte: count } },
        { phoneNumber: 1, blockCount: 1, _id: 0 }  // 필요한 필드만 선택
      );
    },

    // getPhoneRecord 구현
    getPhoneRecord: async (_, { phoneNumber }, { tokenData }) => {
      const { user } = await checkUserOrAdmin(tokenData);
      if (!user) {
        throw new AuthenticationError('로그인이 필요합니다.');
      }
      if (!phoneNumber || typeof phoneNumber !== 'string' || phoneNumber.trim() === '') {
         throw new UserInputError('전화번호 입력이 필요합니다.');
      }

      const normalizedPhoneNumber = phoneNumber.trim();
      const phoneDoc = await PhoneNumber.findOne({ phoneNumber: normalizedPhoneNumber }).lean();
      if (!phoneDoc || !phoneDoc.records || phoneDoc.records.length === 0) return null;

      const userRecord = phoneDoc.records.find(
        (r) => r.userId && String(r.userId) === String(user._id)
      );
      if (!userRecord) return null;

      // createdAt 변환
      let createdAtString = userRecord.createdAt;
      if (userRecord.createdAt instanceof Date) {
         createdAtString = userRecord.createdAt.toISOString();
      }

      // 반환 객체에 phoneNumber 필드 추가 (올바른 구문)
      return {
         // userRecord의 모든 필드를 복사
         ...(userRecord),
         // phoneNumber 필드 추가
         phoneNumber: phoneDoc.phoneNumber,
         // 변환된 createdAt 사용 (혹시 userRecord에 Date 객체가 남아있을 경우 대비)
         createdAt: createdAtString,
      };
    },
  },
};
