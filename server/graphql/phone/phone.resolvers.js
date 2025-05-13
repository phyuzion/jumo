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
  // 1) existingRecords => map by key
  const map = {};
  for (const r of existingRecords) {
    let key;
    if (isAdmin) {
      // 어드민일 때는 전화번호와 시간을 기준으로 키 생성
      const createdAt = r.createdAt instanceof Date ? r.createdAt : new Date(r.createdAt);
      key = `${r.phoneNumber}#${createdAt.toISOString()}`;
    } else {
      // 일반 유저일 때는 userId만으로 키 생성
      const uid = r.userId ? String(r.userId) : '';
      key = uid;
    }
    map[key] = r;
  }

  // 2) newRecords => 병합
  for (const nr of newRecords) {
    // 최종 userId, userName, userType 결정
    let finalUserId = null;
    let finalUserName = '';
    let finalUserType = '일반';

    if (isAdmin) {
      // 어드민의 경우 입력값 사용 (없으면 기본값)
      finalUserName = nr.userName?.trim() || 'Admin';
      finalUserType = nr.userType || '일반';
    } else {
      // 일반 유저의 경우 현재 로그인한 유저 정보 사용
      finalUserId = user._id;
      finalUserName = user.name || '';
      finalUserType = user.userType || '일반';
    }

    let key;
    if (isAdmin) {
      // 어드민일 때는 전화번호와 시간을 기준으로 키 생성
      const createdAt = nr.createdAt ? new Date(nr.createdAt) : new Date();
      key = `${nr.phoneNumber}#${createdAt.toISOString()}`;
    } else {
      // 일반 유저일 때는 userId만으로 키 생성
      key = String(finalUserId);
    }

    let exist = map[key];
    
    if (!exist) {
      // 새 레코드 생성
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
      // 기존 레코드 업데이트
      if (isAdmin) {
        // 어드민의 경우 모든 필드 업데이트 가능
        if (nr.name !== undefined) exist.name = nr.name;
        if (nr.memo !== undefined) exist.memo = nr.memo;
        if (nr.type !== undefined) exist.type = nr.type;
        if (nr.userType !== undefined) exist.userType = nr.userType;
        if (nr.userName !== undefined) exist.userName = nr.userName;
      } else {
        // 일반 유저의 경우 name, memo, type만 업데이트 가능
        // userId, userName, userType은 현재 로그인한 유저 정보로 고정
        if (nr.name !== undefined) exist.name = nr.name;
        if (nr.memo !== undefined) exist.memo = nr.memo;
        if (nr.type !== undefined) exist.type = nr.type;
        exist.userId = finalUserId;
        exist.userName = finalUserName;
        exist.userType = finalUserType;
      }
      // createdAt은 항상 업데이트
      exist.createdAt = nr.createdAt ? new Date(nr.createdAt) : new Date();
    }
  }

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

      const existingDocs = await PhoneNumber.find(
        { phoneNumber: { $in: phoneNumbers } },
        { 
          phoneNumber: 1, 
          records: {
            $map: {
              input: "$records",
              as: "record",
              in: {
                $mergeObjects: [
                  "$$record",
                  { phoneNumber: "$phoneNumber" }
                ]
              }
            }
          },
          type: 1, 
          blockCount: 1, 
          _id: 1 
        }
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

      console.log('[Phone.Resolvers] upsertPhoneRecords bulkWrite done. ops=', bulkOps.length);
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
      // <<< 로그 추가: 입력된 번호 확인 >>>
      console.log(`[getPhoneNumber] Received request for phone: ${normalizedPhoneNumber}`);

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

      // <<< 사용자 정보, PhoneNumber 정보, TodayRecord 정보를 병렬로 조회 (복원) >>>
      // <<< 로그 추가: 사용자 검색 조건 확인 >>>
      console.log(`[getPhoneNumber] Searching for user with phoneNumber: ${normalizedPhoneNumber}`);
      const [registeredUser, phoneDoc, todayDocs] = await Promise.all([
        User.findOne({ phoneNumber: normalizedPhoneNumber }).lean(),
        PhoneNumber.findOne({ phoneNumber: normalizedPhoneNumber }).lean(),
        TodayRecord.find({ phoneNumber: normalizedPhoneNumber }).sort({ createdAt: -1 }).lean(),
      ]);
      // <<< 로그 추가: 사용자 검색 결과 확인 >>>
      console.log(`[getPhoneNumber] Found user result: ${registeredUser ? registeredUser.loginId : 'null'}`);

      // TodayRecord 포맷팅 (항상 수행) (복원)
      const formattedTodayRecords = todayDocs.map(record => ({
        id: record._id.toString(),
        phoneNumber: record.phoneNumber,
        userName: record.userName,
        userType: record.userType,
        interactionType: record.interactionType,
        createdAt: record.createdAt.toISOString(),
      }));

      // <<< 최종 결과 조합 (복원 및 수정) >>>
      if (registeredUser) {
        // 사용자를 찾은 경우
        console.log('[getPhoneNumber] Constructing response for REGISTERED USER:', registeredUser.loginId);
        // <<< phoneDoc이 null일 경우에도 기본값 제공 및 필드 이름 확인 >>>
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
          isRegisteredUser: true, // <<< 확실히 true 설정
          registeredUserInfo: { // <<< 확실히 객체 생성 및 값 할당
            userName: registeredUser.name || '',
            userRegion: registeredUser.region, // 스키마에서 Nullable이므로 그대로 전달
            userType: registeredUser.userType || '일반',
          },
        };
      } else {
        // 사용자를 찾지 못한 경우
        console.log('[getPhoneNumber] Constructing response for NON-registered number.');
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
