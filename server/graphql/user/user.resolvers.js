// graphql/user/user.resolvers.js

const bcrypt = require('bcrypt');
const {
  UserInputError,
  AuthenticationError,
  ForbiddenError,
} = require('apollo-server-errors');
const { GraphQLJSON } = require('graphql-type-json');

const jwt = require('jsonwebtoken');
const SECRET_KEY = process.env.JWT_SECRET || 'someRandomSecretKey';

const Admin = require('../../models/Admin');
const User = require('../../models/User');
const PhoneNumber = require('../../models/PhoneNumber'); // userRecords 조회용
const TodayRecord = require('../../models/TodayRecord');

function generateAccessToken(payload) {
  return jwt.sign(payload, SECRET_KEY, { expiresIn: '1d' });
}
function generateRefreshToken(payload) {
  return jwt.sign(payload, SECRET_KEY, { expiresIn: '7d' });
}
function verifyRefreshToken(token) {
  try {
    return jwt.verify(token, SECRET_KEY);
  } catch (e) {
    return null;
  }
}

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

// 권한 체크
async function checkAdminValid(tokenData) {
  if (!tokenData?.adminId) {
    throw new ForbiddenError('관리자 권한이 필요합니다.');
  }
}
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

/* =========================================================
   새 유틸:
   - pushNewLog(arr, newLog, max=200)
   - 중복 체크 -> 없으면 arr.unshift(newLog)
   - if arr.length > max => arr.pop() (가장 오래된 제거)
========================================================= */
function pushNewLog(logArray, newLog, maxLen = 200) {
  const newLogKey = JSON.stringify(newLog);
  const isDup = logArray.some((item) => JSON.stringify(item) === newLogKey);
  if (isDup) return;
  logArray.unshift(newLog);
  if (logArray.length > maxLen) {
    logArray.pop();
  }
}

module.exports = {
  Query: {
    // (Admin 전용) 유저 전화 내역
    getUserCallLog: async (_, { userId }, { tokenData }) => {
      if (!tokenData?.adminId) {
        throw new ForbiddenError('관리자 권한이 필요합니다.');
      }
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
      if (!tokenData?.adminId) {
        throw new ForbiddenError('관리자 권한이 필요합니다.');
      }
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

    // (새로 추가) 로그인 유저의 settings 조회
    getUserSetting: async (_, __, { tokenData }) => {
      const user = await checkUserValid(tokenData);
      return user.settings; // String
    },

    getUserBlockNumbers: async (_, { userId }, { tokenData }) => {
      if (!tokenData?.adminId) {
        throw new ForbiddenError('관리자 권한이 필요합니다.');
      }
      const user = await User.findById(userId);
      if (!user) throw new UserInputError('해당 유저가 존재하지 않습니다.');

      return user.blockList || [];
    },
  },

  Mutation: {
    // (Admin 전용) 유저 생성
    createUser: async (_, { phoneNumber, name, region }, { tokenData }) => {
      await checkAdminValid(tokenData);
      if (!phoneNumber || !name) {
        throw new UserInputError('phoneNumber와 name은 필수 입력입니다.');
      }

      const systemId = generateRandomString(6);
      const loginId = generateRandomString(6);
      const generatedPassword = generateRandomString(6); // 임시 비번

      const hashedPw = await bcrypt.hash(generatedPassword, 10);

      const oneMonthLater = new Date();
      oneMonthLater.setMonth(oneMonthLater.getMonth() + 1);

      const newUser = new User({
        systemId,
        loginId,
        password: hashedPw,
        name,
        phoneNumber,
        validUntil: oneMonthLater,
        region: region || '',         // 추가된 필드
      });
      await newUser.save();

      return {
        user: newUser,
        tempPassword: generatedPassword,
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
      await user.save();

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
      await user.save();

      return {
        success: true,
        user,
      };
    },

    // (Admin 전용) 유저 정보 업데이트
    updateUser: async (
      _,
      { userId, name, phoneNumber, validUntil, type, region },
      { tokenData }
    ) => {
      await checkAdminValid(tokenData);

      const user = await User.findById(userId);
      if (!user) {
        throw new UserInputError('유저를 찾을 수 없습니다.');
      }
      if (name !== undefined) user.name = name;
      if (phoneNumber !== undefined) user.phoneNumber = phoneNumber;
      if (type !== undefined) user.type = type;
      if (validUntil !== undefined) {
        user.validUntil = new Date(validUntil);
      }
      if (region !== undefined) {
        user.region = region;
      }

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
      await user.save();
      return newPass;
    },

    // 통화내역 upsert
    updateCallLog: async (_, { logs }, { tokenData }) => {
      const user = await checkUserValid(tokenData);

      // 1. User의 callLogs 업데이트 (기존 로직 유지)
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
      await user.save();

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

        // TodayRecord 업데이트
        for (const log of recentLogs) {
          let dt = new Date(log.time);
          if (isNaN(dt.getTime())) {
            const epoch = parseFloat(log.time);
            if (!isNaN(epoch)) dt = new Date(epoch);
          }

          const existingRecord = await TodayRecord.findOne({
            phoneNumber: log.phoneNumber,
            userName: user.name,
          });

          if (existingRecord) {
            existingRecord.userType = user.type;  // User의 type을 저장
            existingRecord.callType = log.callType;  // callType은 문자열 그대로 저장
            existingRecord.createdAt = dt;
            await existingRecord.save();
          } else {
            const record = new TodayRecord({
              phoneNumber: log.phoneNumber,
              userName: user.name,
              userType: user.type,  // User의 type을 저장
              callType: log.callType,  // callType은 문자열 그대로 저장
              createdAt: dt,
            });
            await record.save();
          }
        }
      } catch (error) {
        console.error('TodayRecord 업데이트 실패:', error);
        // TodayRecord 업데이트 실패는 전체 mutation을 실패시키지 않음
      }

      return true;
    },

    // 문자내역 upsert
    updateSMSLog: async (_, { logs }, { tokenData }) => {
      const user = await checkUserValid(tokenData);

      for (const log of logs) {
        let dt = new Date(log.time);
        if (isNaN(dt.getTime())) {
          const epoch = parseFloat(log.time);
          if (!isNaN(epoch)) dt = new Date(epoch);
        }
        const newLog = {
          phoneNumber: log.phoneNumber,
          time: dt,
          content: log.content || '',
          smsType: log.smsType,
        };
        pushNewLog(user.smsLogs, newLog, 200);
      }
      await user.save();
      return true;
    },

    // (새로 추가) 로그인 유저의 settings 저장
    setUserSetting: async (_, { settings }, { tokenData }) => {
      const user = await checkUserValid(tokenData);
      user.settings = settings;
      await user.save();
      return true;
    },

    updateBlockedNumbers: async (_, { numbers }, { tokenData }) => {
      const user = await checkUserValid(tokenData);
      user.blockList = numbers;
      await user.save();
      return user.blockList;
    },
  },
};
