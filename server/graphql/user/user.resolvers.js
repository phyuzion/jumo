// graphql/user/user.resolvers.js

const bcrypt = require('bcrypt');
const {
  UserInputError,
  AuthenticationError,
  ForbiddenError,
} = require('apollo-server-errors');
const { GraphQLJSON } = require('graphql-type-json');
const { withTransaction } = require('../../utils/transaction');
const mongoose = require('mongoose');

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
const CallLog = require('../../models/CallLog');
const SmsLog = require('../../models/SmsLog');

/* 랜덤 문자열 생성 함수 (영문+숫자 6자리) */
function generateRandomString(length = 6) {
  const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
  let result = '';
  for (let i = 0; i < length; i++) {
    const randomIndex = Math.floor(Math.random() * chars.length);
    result += chars[randomIndex];
  }
  return result;
}

module.exports = {
  Query: {
    // (Admin 전용) 유저 전화 내역
    getUserCallLog: async (_, { userId }, { tokenData }) => {
      await checkAdminValid(tokenData);
      const user = await User.findById(userId);
      if (!user) throw new UserInputError('해당 유저가 존재하지 않습니다.');

      // 새로운 CallLog 모델에서 로그 조회
      const logs = await CallLog.find({ userId })
        .sort({ time: -1 })
        .limit(200);

      return logs.map(log => ({
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

      // 새로운 SmsLog 모델에서 로그 조회
      const logs = await SmsLog.find({ userId })
        .sort({ time: -1 })
        .limit(200);

      return logs.map(log => ({
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

      // userId를 ObjectId로 변환
      const userObjectId = new mongoose.Types.ObjectId(userId);

      // phoneNumber 컬렉션에서 records.userId == userId 인 문서들 찾기
      const phoneDocs = await PhoneNumber.find({ 'records.userId': userObjectId });

      let recordList = [];
      for (const doc of phoneDocs) {
        const matchedRecords = doc.records.filter(
          (r) => r.userId && r.userId.toString() === userObjectId.toString()
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
    createUser: async (_, { loginId, phoneNumber, name, userType, region, grade }, { tokenData }) => {
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
      const tempPassword = Math.random().toString(36).slice(-6);
      const hashedPassword = await bcrypt.hash(tempPassword, 10);

      const newUser = new User({
        loginId,
        phoneNumber,
        name,
        userType,
        region,
        grade,
        password: hashedPassword,
        validUntil: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000), // 30일
      });

      await newUser.save();
      return {
        user: newUser,
        tempPassword
      };
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
    updateUser: async (_, { userId, name, phoneNumber, userType, region, grade, validUntil }, { tokenData }) => {
      // 1) 관리자만 가능
      await checkAdminValid(tokenData);

      const user = await User.findById(userId);
      if (!user) {
        throw new UserInputError('해당 유저 없음');
      }

      if (name !== undefined) user.name = name;
      if (phoneNumber !== undefined) user.phoneNumber = phoneNumber;
      if (userType !== undefined) user.userType = userType;
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

      // 시간 파싱 함수
      function parseDateTime(time) {
        let dt = new Date(time);
        if (isNaN(dt.getTime())) {
          const epoch = parseFloat(time);
          if (!isNaN(epoch)) dt = new Date(epoch);
        }
        if (isNaN(dt.getTime())) {
          dt = new Date();
        }
        return dt;
      }

      // 1. CallLog 업데이트
      const callLogs = logs.map(log => ({
        userId: user._id,
        phoneNumber: log.phoneNumber,
        time: parseDateTime(log.time),
        callType: log.callType
      }));

      // 중복 제거 및 시간순 정렬
      const uniqueLogs = callLogs.filter((log, index, self) =>
        index === self.findIndex((t) => 
          t.phoneNumber === log.phoneNumber && 
          t.time.getTime() === log.time.getTime()
        )
      ).sort((a, b) => b.time - a.time).slice(0, 200);

      // bulkWrite로 한번에 처리
      await withTransaction(async (session) => {
        const operations = uniqueLogs.map(log => ({
          updateOne: {
            filter: {
              userId: log.userId,
              phoneNumber: log.phoneNumber,
              time: log.time
            },
            update: { $set: log },
            upsert: true
          }
        }));

        if (operations.length > 0) {
          await CallLog.bulkWrite(operations, { 
            session,
            ordered: false
          });
        }
      });

      // 2. TodayRecord 업데이트
      try {
        const oneDayAgo = new Date();
        oneDayAgo.setDate(oneDayAgo.getDate() - 1);
        
        const recentLogs = logs.filter(log => {
          const dt = parseDateTime(log.time);
          return dt >= oneDayAgo;
        });

        if (recentLogs.length > 0) {
          await withTransaction(async (session) => {
            // 각 로그에 대해 upsert 수행
            for (const log of recentLogs) {
              const dt = parseDateTime(log.time);
              
              // 기존 레코드 조회
              const existing = await TodayRecord.findOne({
                phoneNumber: log.phoneNumber,
                userName: user.name
              }).session(session);

              if (existing) {
                // 기존 레코드가 있고 새로운 통화가 더 최신인 경우만 업데이트
                if (dt > existing.createdAt) {
                  await TodayRecord.findOneAndUpdate(
                    { _id: existing._id },
                    {
                      $set: {
                        userType: user.userType,
                        callType: log.callType,
                        createdAt: dt
                      }
                    },
                    { session }
                  );
                }
              } else {
                // 새 레코드 생성
                await TodayRecord.create([{
                  phoneNumber: log.phoneNumber,
                  userName: user.name,
                  userType: user.userType,
                  callType: log.callType,
                  createdAt: dt
                }], { session });
              }
            }
          });
        }
      } catch (error) {
        console.error('TodayRecord 업데이트 실패:', error);
        throw new Error('통화 기록 업데이트 중 오류가 발생했습니다.');
      }

      return true;
    },

    // 문자내역 upsert
    updateSMSLog: async (_, { logs }, { tokenData }) => {
      const user = await checkUserValid(tokenData);

      // 시간 파싱 함수
      function parseDateTime(time) {
        let dt = new Date(time);
        if (isNaN(dt.getTime())) {
          const epoch = parseFloat(time);
          if (!isNaN(epoch)) dt = new Date(epoch);
        }
        if (isNaN(dt.getTime())) {
          dt = new Date();
        }
        return dt;
      }

      // 1. SmsLog 업데이트
      const smsLogs = logs.map(log => ({
        userId: user._id,
        phoneNumber: log.phoneNumber,
        time: parseDateTime(log.time),
        content: log.content,
        smsType: log.smsType
      }));

      // 중복 제거 및 시간순 정렬
      const uniqueLogs = smsLogs
        .filter((log, index, self) =>
          index === self.findIndex((t) => 
            t.phoneNumber === log.phoneNumber && 
            t.time.getTime() === log.time.getTime()
          )
        )
        .sort((a, b) => b.time - a.time)
        .slice(0, 200);

      // bulkWrite로 한번에 처리
      await withTransaction(async (session) => {
        const operations = uniqueLogs.map(log => ({
          updateOne: {
            filter: {
              userId: log.userId,
              phoneNumber: log.phoneNumber,
              time: log.time
            },
            update: { $set: log },
            upsert: true
          }
        }));

        if (operations.length > 0) {
          await SmsLog.bulkWrite(operations, { 
            session,
            ordered: false
          });
        }
      });

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
