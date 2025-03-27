// graphql/user/user.resolvers.js

const bcrypt = require('bcrypt');
const {
  UserInputError,
  AuthenticationError,
  ForbiddenError,
} = require('apollo-server-errors');
const { GraphQLJSON } = require('graphql-type-json');
const { withTransaction } = require('../../utils/transaction');

const {
  generateAccessToken,
  generateRefreshToken,
  verifyRefreshToken,
  checkAdminValid,
  checkUserValid,
  SECRET_KEY
} = require('../auth/utils');

const Admin = require('../../models/Admin');
const User = require('../../models/User');
const PhoneNumber = require('../../models/PhoneNumber'); // userRecords 조회용
const TodayRecord = require('../../models/TodayRecord');

/* 랜덤 문자열 생성 함수 (영문+숫자 6자리) */
function generateRandomString(length = 6) {
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
  let result = '';
  for (let i = 0; i < length; i++) {
    const randomIndex = Math.floor(Math.random() * chars.length);
    result += chars[randomIndex];
  }
  return result;
}

/* =========================================================
   새 유틸:
   - pushNewLog(arr, newLog, max=200)
   - 중복 체크 -> 없으면 arr.unshift(newLog)
   - if arr.length > max => arr.pop() (가장 오래된 제거)
========================================================= */
function pushNewLog(logArray, newLog, maxLen = 200) {
  // 시간을 밀리초 단위로 변환하여 비교
  const newLogTime = newLog.time.getTime();
  
  // 이미 같은 시간의 로그가 있는지 확인
  const isDup = logArray.some(item => {
    // phoneNumber와 time이 같으면 중복으로 간주
    return item.phoneNumber === newLog.phoneNumber && 
           item.time.getTime() === newLogTime;
  });

  if (isDup) return;

  // 중복이 아니면 배열 앞에 추가
  logArray.unshift(newLog);
  
  // 최대 길이 제한
  if (logArray.length > maxLen) {
    logArray.pop();
  }
}

module.exports = {
  Query: {
    // (Admin 전용) 유저 전화 내역
    getUserCallLog: async (_, { userId }, { tokenData }) => {
      await checkAdminValid(tokenData);
      const user = await User.findById(userId);
      if (!user) throw new UserInputError('해당 유저가 존재하지 않습니다.');

      return user.callLogs.map((log) => ({
        phoneNumber: log.phoneNumber,
        time: log.time.toISOString(),
        callType: log.callType,
      }));
    },

    // (Admin 전용) 유저 문자 내역
    getUserSMSLog: async (_, { userId }, { tokenData }) => {
      await checkAdminValid(tokenData);
      const user = await User.findById(userId);
      if (!user) throw new UserInputError('해당 유저가 존재하지 않습니다.');

      return user.smsLogs.map((log) => ({
        phoneNumber: log.phoneNumber,
        time: log.time.toISOString(),
        content: log.content || '',
        smsType: log.smsType,
      }));
    },

    // (Admin 전용) 모든 유저 조회
    getAllUsers: async (_, __, { tokenData }) => {
      await checkAdminValid(tokenData);
      return User.find({});
    },

    // 특정 유저 + 그 유저가 저장한 전화번호 레코드 조회
    getUserRecords: async (_, { userId }, { tokenData }) => {
      // 관리자이거나 본인만 가능
      if (tokenData?.adminId) {
        // pass
      } else {
        if (!tokenData?.userId || tokenData.userId !== userId) {
          throw new ForbiddenError('본인 계정만 조회 가능합니다.');
        }
      }

      const user = await User.findById(userId);
      if (!user) {
        throw new UserInputError('해당 유저가 존재하지 않습니다.');
      }

      // phoneNumber 컬렉션에서 records.userId == userId 인 문서들 찾기
      const phoneDocs = await PhoneNumber.find({ 'records.userId': userId });

      let recordList = [];
      for (const doc of phoneDocs) {
        const matchedRecords = doc.records.filter(
          (r) => r.userId.toString() === userId
        );
        for (const rec of matchedRecords) {
          recordList.push({
            phoneNumber: doc.phoneNumber,
            name: rec.name,
            memo: rec.memo,
            type: rec.type || 0,
            createdAt: rec.createdAt,
          });
        }
      }

      return {
        user,
        records: recordList,
      };
    },

    // 현재 로그인된 유저의 settings 조회
    getUserSetting: async (_, __, { tokenData }) => {
      const user = await checkUserValid(tokenData);
      return user.settings;
    },

    getUserBlockNumbers: async (_, __, { tokenData }) => {
      const user = await checkUserValid(tokenData);
      return user.blockList || [];
    },
  },

  Mutation: {
    // 유저 생성
    createUser: async (_, { loginId, phoneNumber, name, type, region, grade }, { tokenData }) => {
      // 1) 관리자만 가능
      await checkAdminValid(tokenData);

      // 2) loginId 중복 체크
      const existingUser = await User.findOne({ loginId });
      if (existingUser) {
        throw new UserInputError('이미 사용 중인 ID입니다.');
      }

      // 3) loginId 형식 체크 (영문+숫자)
      if (!/^[a-zA-Z0-9]+$/.test(loginId)) {
        throw new UserInputError('ID는 영문과 숫자만 사용 가능합니다.');
      }

      // 4) 임시 비밀번호 생성 (8자리)
      const tempPassword = Math.random().toString(36).slice(-8);
      const hashedPassword = await bcrypt.hash(tempPassword, 10);

      const newUser = new User({
        loginId,
        phoneNumber,
        name,
        type,
        region,
        grade,
        password: hashedPassword,
        validUntil: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000), // 30일
      });

      await newUser.save();
      return { ...newUser.toObject(), tempPassword };
    },

    // 유저 로그인
    userLogin: async (_, { loginId, password, phoneNumber }) => {
      if (!loginId || !phoneNumber || !password) {
        throw new UserInputError('필수 입력 누락');
      }
      const user = await User.findOne({ loginId, phoneNumber });
      if (!user) {
        throw new UserInputError('사용자를 찾을 수 없습니다.');
      }
      if (user.validUntil && user.validUntil < new Date()) {
        throw new ForbiddenError('유효 기간 만료');
      }

      const isMatch = await bcrypt.compare(password, user.password);
      if (!isMatch) {
        throw new UserInputError('비밀번호가 올바르지 않습니다.');
      }

      const accessToken = generateAccessToken({ userId: user._id });
      const refreshToken = generateRefreshToken({ userId: user._id });
      user.refreshToken = refreshToken;
      await withTransaction(async (session) => {
        await user.save({ session });
      });

      return { accessToken, refreshToken, user };
    },

    // 유저 비번 변경 (본인)
    userChangePassword: async (_, { oldPassword, newPassword }, { tokenData }) => {
      const user = await checkUserValid(tokenData);
      if (!oldPassword || !newPassword) {
        throw new UserInputError('oldPassword, newPassword는 필수입니다.');
      }

      const isMatch = await bcrypt.compare(oldPassword, user.password);
      if (!isMatch) {
        throw new UserInputError('기존 비밀번호가 올바르지 않습니다.');
      }

      user.password = await bcrypt.hash(newPassword, 10);
      await withTransaction(async (session) => {
        await user.save({ session });
      });

      return {
        success: true,
        user,
      };
    },

    // 유저 수정
    updateUser: async (_, { userId, name, phoneNumber, type, region, grade, validUntil }, { tokenData }) => {
      // 1) 관리자만 가능
      await checkAdminValid(tokenData);

      const user = await User.findById(userId);
      if (!user) {
        throw new UserInputError('해당 유저 없음');
      }

      if (name !== undefined) user.name = name;
      if (phoneNumber !== undefined) user.phoneNumber = phoneNumber;
      if (type !== undefined) user.type = type;
      if (region !== undefined) user.region = region;
      if (grade !== undefined) user.grade = grade;
      if (validUntil !== undefined) user.validUntil = new Date(validUntil);

      await user.save();
      return user;
    },

    // (Admin 전용) 특정 유저 비번 초기화
    resetUserPassword: async (_, { userId }, { tokenData }) => {
      await checkAdminValid(tokenData);
      const user = await User.findById(userId);
      if (!user) {
        throw new UserInputError('유저를 찾을 수 없습니다.');
      }

      const newPass = generateRandomString(6);
      user.password = await bcrypt.hash(newPass, 10);
      await withTransaction(async (session) => {
        await user.save({ session });
      });
      return newPass;
    },

    // 통화내역 upsert
    updateCallLog: async (_, { logs }, { tokenData }) => {
      const user = await checkUserValid(tokenData);

      // 1. User의 callLogs 업데이트
      for (const log of logs) {
        let dt = new Date(log.time);
        if (isNaN(dt.getTime())) {
          const epoch = parseFloat(log.time);
          if (!isNaN(epoch)) dt = new Date(epoch);
        }
        const newLog = {
          phoneNumber: log.phoneNumber,
          time: dt,
          callType: log.callType,
        };
        pushNewLog(user.callLogs, newLog, 200);
      }
      await withTransaction(async (session) => {
        await user.save({ session });
      });

      // 2. TodayRecord 업데이트
      try {
        // 24시간 이내의 새로운 로그들만 필터링
        const oneDayAgo = new Date();
        oneDayAgo.setDate(oneDayAgo.getDate() - 1);
        
        const recentLogs = logs.filter(log => {
          let dt = new Date(log.time);
          if (isNaN(dt.getTime())) {
            const epoch = parseFloat(log.time);
            if (!isNaN(epoch)) dt = new Date(epoch);
          }
          return dt >= oneDayAgo;
        });

        if (recentLogs.length > 0) {
          await withTransaction(async (session) => {
            // 1. 기존 레코드들을 한 번에 조회
            const existingRecords = await TodayRecord.find({
              phoneNumber: { $in: recentLogs.map(log => log.phoneNumber) },
              userName: user.name
            }).session(session);

            // 2. 기존 레코드들을 Map으로 변환하여 빠른 조회 가능하게 함
            const existingMap = new Map(
              existingRecords.map(record => [record.phoneNumber, record])
            );

            // 3. 업데이트할 레코드와 새로 생성할 레코드를 분리
            const updates = [];
            const inserts = [];

            for (const log of recentLogs) {
              let dt = new Date(log.time);
              if (isNaN(dt.getTime())) {
                const epoch = parseFloat(log.time);
                if (!isNaN(epoch)) dt = new Date(epoch);
              }

              const existing = existingMap.get(log.phoneNumber);
              if (existing) {
                // 기존 레코드가 있고 새로운 통화가 더 최신인 경우만 업데이트
                if (dt > existing.createdAt) {
                  updates.push({
                    updateOne: {
                      filter: { _id: existing._id },
                      update: {
                        $set: {
                          userType: user.type,
                          callType: log.callType,
                          createdAt: dt
                        }
                      }
                    }
                  });
                }
              } else {
                // 새 레코드 생성
                inserts.push({
                  insertOne: {
                    document: {
                      phoneNumber: log.phoneNumber,
                      userName: user.name,
                      userType: user.type,
                      callType: log.callType,
                      createdAt: dt
                    }
                  }
                });
              }
            }

            // 4. 한 번의 bulkWrite로 모든 작업 실행
            if (updates.length > 0 || inserts.length > 0) {
              await TodayRecord.bulkWrite([...updates, ...inserts], { session });
            }
          });
        }
      } catch (error) {
        console.error('TodayRecord 업데이트 실패:', error);
        // TodayRecord 업데이트 실패는 전체 mutation 실패로 이어지지 않도록 함
      }

      return true;
    },

    // 문자내역 upsert
    updateSMSLog: async (_, { logs }, { tokenData }) => {
      const user = await checkUserValid(tokenData);
      console.log(`[updateSMSLog] 시작 - 유저: ${user.name}, 로그 수: ${logs.length}`);

      // 1. User의 smsLogs 업데이트
      for (const log of logs) {
        let dt = new Date(log.time);
        if (isNaN(dt.getTime())) {
          const epoch = parseFloat(log.time);
          if (!isNaN(epoch)) dt = new Date(epoch);
        }
        const newLog = {
          phoneNumber: log.phoneNumber,
          time: dt,
          content: log.content,
          smsType: log.smsType,
        };
        pushNewLog(user.smsLogs, newLog, 200);
      }
      console.log(`[updateSMSLog] User.smsLogs 업데이트 완료 - 최종 로그 수: ${user.smsLogs.length}`);
      
      await withTransaction(async (session) => {
        await user.save({ session });
      });

      // 2. TodayRecord 업데이트
      try {
        // 24시간 이내의 새로운 로그들만 필터링
        const oneDayAgo = new Date();
        oneDayAgo.setDate(oneDayAgo.getDate() - 1);
        
        const recentLogs = logs.filter(log => {
          let dt = new Date(log.time);
          if (isNaN(dt.getTime())) {
            const epoch = parseFloat(log.time);
            if (!isNaN(epoch)) dt = new Date(epoch);
          }
          return dt >= oneDayAgo;
        });
        console.log(`[updateSMSLog] 최근 24시간 로그 수: ${recentLogs.length}`);

        if (recentLogs.length > 0) {
          await withTransaction(async (session) => {
            console.log(`[updateSMSLog] TodayRecord 트랜잭션 시작`);
            
            // 1. 기존 레코드들을 한 번에 조회
            const existingRecords = await TodayRecord.find({
              phoneNumber: { $in: recentLogs.map(log => log.phoneNumber) },
              userName: user.name
            }).session(session);
            console.log(`[updateSMSLog] 기존 TodayRecord 조회 완료 - ${existingRecords.length}개`);

            // 2. 기존 레코드들을 Map으로 변환하여 빠른 조회 가능하게 함
            const existingMap = new Map(
              existingRecords.map(record => [record.phoneNumber, record])
            );

            // 3. 업데이트할 레코드와 새로 생성할 레코드를 분리
            const updates = [];
            const inserts = [];

            for (const log of recentLogs) {
              let dt = new Date(log.time);
              if (isNaN(dt.getTime())) {
                const epoch = parseFloat(log.time);
                if (!isNaN(epoch)) dt = new Date(epoch);
              }

              const existing = existingMap.get(log.phoneNumber);
              if (existing) {
                // 기존 레코드가 있고 새로운 문자메시지가 더 최신인 경우만 업데이트
                if (dt > existing.createdAt) {
                  updates.push({
                    updateOne: {
                      filter: { _id: existing._id },
                      update: {
                        $set: {
                          userType: user.type,
                          smsType: log.smsType,
                          createdAt: dt
                        }
                      }
                    }
                  });
                }
              } else {
                // 새 레코드 생성
                inserts.push({
                  insertOne: {
                    document: {
                      phoneNumber: log.phoneNumber,
                      userName: user.name,
                      userType: user.type,
                      smsType: log.smsType,
                      createdAt: dt
                    }
                  }
                });
              }
            }

            console.log(`[updateSMSLog] TodayRecord 업데이트/삽입 준비 완료 - 업데이트: ${updates.length}개, 삽입: ${inserts.length}개`);

            // 4. 한 번의 bulkWrite로 모든 작업 실행
            if (updates.length > 0 || inserts.length > 0) {
              const result = await TodayRecord.bulkWrite([...updates, ...inserts], { session });
              console.log(`[updateSMSLog] TodayRecord bulkWrite 완료 - 수정: ${result.modifiedCount}, 삽입: ${result.insertedCount}`);
            } else {
              console.log(`[updateSMSLog] TodayRecord 업데이트/삽입 없음`);
            }
            
            console.log(`[updateSMSLog] TodayRecord 트랜잭션 완료`);
          });
        }
      } catch (error) {
        console.error('[updateSMSLog] TodayRecord 업데이트 실패:', error);
        // TodayRecord 업데이트 실패는 전체 mutation 실패로 이어지지 않도록 함
      }

      console.log(`[updateSMSLog] 전체 작업 완료`);
      return true;
    },

    // (새로 추가) 로그인 유저의 settings 저장
    setUserSetting: async (_, { settings }, { tokenData }) => {
      const user = await checkUserValid(tokenData);
      user.settings = settings;
      await withTransaction(async (session) => {
        await user.save({ session });
      });
      return true;
    },

    updateBlockedNumbers: async (_, { numbers }, { tokenData }) => {
      const user = await checkUserValid(tokenData);
      user.blockList = numbers;
      await withTransaction(async (session) => {
        await user.save({ session });
      });
      return user.blockList;
    },
  },
};
