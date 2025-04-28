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

      const existingDocs = await PhoneNumber.find({
        phoneNumber: { $in: phoneNumbers }
      }).lean();

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

      console.log('[Phone.Resolvers] upsertPhoneRecords bulkWrite done. ops=', bulkOps.length);
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
        const user = await User.findById(tokenData.userId).select('searchCount lastSearchTime grade');
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

      // <<< PhoneNumber 정보와 TodayRecord 정보를 병렬로 조회 >>>
      const [phoneDoc, todayDocs] = await Promise.all([
        PhoneNumber.findOne({ phoneNumber }).lean(), // lean() 사용 권장
        TodayRecord.find({ phoneNumber }).sort({ createdAt: -1 }).lean(),
      ]);

      if (!phoneDoc) return null; // PhoneNumber 정보가 없으면 null 반환

      // <<< TodayRecord 결과 포맷팅 (기존 TodayRecord Resolver와 유사하게) >>>
      const formattedTodayRecords = todayDocs.map(record => ({
        id: record._id,
        phoneNumber: record.phoneNumber,
        userName: record.userName,
        userType: record.userType,
        interactionType: record.interactionType,
        createdAt: record.createdAt.toISOString(), // Date -> ISO String
      }));

      // <<< 결과 객체에 todayRecords 추가하여 반환 >>>
      return {
        ...phoneDoc, // 기존 phoneDoc 필드들
        id: phoneDoc._id, // _id -> id 매핑 (스키마에 id!로 정의됨)
        records: phoneDoc.records.map(r => ({
          ...r,
          createdAt: r.createdAt?.toISOString() // Record 내부 createdAt도 ISO String으로
        })),
        todayRecords: formattedTodayRecords,
      };
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
