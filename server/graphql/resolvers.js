// graphql/resolvers.js

require('dotenv').config();
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const {
  UserInputError,
  AuthenticationError,
  ForbiddenError,
} = require('apollo-server-errors');

const Admin = require('../models/Admin');
const User = require('../models/User');
const PhoneNumber = require('../models/PhoneNumber');

const SECRET_KEY = process.env.JWT_SECRET || 'someRandomSecretKey';
const ACCESS_TOKEN_EXPIRE = '1h';  // Access Token 1시간
const REFRESH_TOKEN_EXPIRE = '7d'; // Refresh Token 7일

/* =========================================================
   JWT 생성 관련 함수
========================================================= */
function generateAccessToken(payload) {
  return jwt.sign(payload, SECRET_KEY, { expiresIn: ACCESS_TOKEN_EXPIRE });
}

function generateRefreshToken(payload) {
  return jwt.sign(payload, SECRET_KEY, { expiresIn: REFRESH_TOKEN_EXPIRE });
}

/* =========================================================
   Refresh Token 유효성 검증
========================================================= */
function verifyRefreshToken(token) {
  try {
    return jwt.verify(token, SECRET_KEY);
  } catch (e) {
    return null;
  }
}

/* =========================================================
   사용자 / 어드민 권한 체크 시
   - validUntil 만료 여부도 함께 체크 (User 한정)
========================================================= */
async function checkUserValid(tokenData) {
  if (!tokenData?.userId) {
    throw new AuthenticationError('로그인이 필요합니다.');
  }

  // DB에서 유저 조회
  const user = await User.findById(tokenData.userId);
  if (!user) {
    throw new ForbiddenError('유효하지 않은 유저입니다.');
  }

  // validUntil이 지났으면 에러
  if (user.validUntil && user.validUntil < new Date()) {
    throw new ForbiddenError('유효 기간이 만료된 계정입니다.');
  }
  return user;
}

function checkAdminValid(tokenData) {
  if (!tokenData?.adminId) {
    throw new ForbiddenError('관리자 권한이 필요합니다.');
  }
}

/* 랜덤 문자열 생성 함수 (숫자+영문 6자리) */
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
   리졸버 구현
========================================================= */

const resolvers = {
  Query: {
    // Admin 전용: 전체 유저 조회
    getAllUsers: async (_, __, { tokenData }) => {
      checkAdminValid(tokenData);
      return User.find({});
    },

    // 특정 유저 1명 조회 (Admin 전용 or 본인만)
    getUser: async (_, { userId }, { tokenData }) => {
      if (!tokenData) {
        throw new AuthenticationError('로그인이 필요합니다.');
      }

      // 만약 admin이면 무조건 가능, 일반 유저면 본인만 가능
      if (tokenData.adminId) {
        // 관리자 OK
      } else if (tokenData.userId !== userId) {
        throw new ForbiddenError('본인 계정만 조회 가능합니다.');
      }

      const user = await User.findById(userId);
      if (!user) {
        throw new UserInputError('해당 유저가 존재하지 않습니다.');
      }
      return user;
    },

    // 특정 전화번호 조회 (Admin, User 모두 가능)
    getPhoneNumber: async (_, { phoneNumber }, { tokenData }) => {
      if (!tokenData) throw new AuthenticationError('로그인이 필요합니다.');
      // 단순 조회: Admin, User 구분 없이 허용
      if (!phoneNumber || phoneNumber.trim() === '') {
        throw new UserInputError('phoneNumber가 비어 있습니다.');
      }
      return PhoneNumber.findOne({ phoneNumber });
    },

    // 타입으로 전화번호 조회 (Admin, User 모두)
    getPhoneNumbersByType: async (_, { type }, { tokenData }) => {
      if (!tokenData) throw new AuthenticationError('로그인이 필요합니다.');
      return PhoneNumber.find({ type });
    },
  },

  Mutation: {
    /* =========================
       Admin 관련
    ========================= */

    // Admin 생성
    createAdmin: async (_, { username, password }) => {
      if (!username || !password) {
        throw new UserInputError('username과 password는 필수 입력입니다.');
      }
      const hashedPw = await bcrypt.hash(password, 10);
      const admin = new Admin({
        username,
        password: hashedPw,
      });
      await admin.save();
      return admin;
    },

    // Admin 로그인 -> accessToken + refreshToken
    adminLogin: async (_, { username, password }) => {
      const admin = await Admin.findOne({ username });
      if (!admin) {
        throw new UserInputError('존재하지 않는 Admin입니다.');
      }
      const isMatch = await bcrypt.compare(password, admin.password);
      if (!isMatch) {
        throw new UserInputError('비밀번호가 올바르지 않습니다.');
      }

      // 발급
      const accessToken = generateAccessToken({ adminId: admin._id });
      const refreshToken = generateRefreshToken({ adminId: admin._id });

      // DB에 refreshToken 저장
      admin.refreshToken = refreshToken;
      await admin.save();

      return {
        accessToken,
        refreshToken,
      };
    },

    /* =========================
       User 관련
    ========================= */

    // (Admin 전용) 유저 생성
    createUser: async (_, { phoneNumber, name }, { tokenData }) => {
      checkAdminValid(tokenData);

      if (!phoneNumber || !name) {
        throw new UserInputError('phoneNumber와 name은 필수 입력입니다.');
      }

      const systemId = generateRandomString(6);
      const loginId = generateRandomString(6);
      const generatedPassword = generateRandomString(6); // 임시 비번

      const hashedPw = await bcrypt.hash(generatedPassword, 10);

      // 유효기간: 1달 뒤
      const oneMonthLater = new Date();
      oneMonthLater.setMonth(oneMonthLater.getMonth() + 1);

      const newUser = new User({
        systemId,
        loginId,
        password: hashedPw,
        name,
        phoneNumber,
        validUntil: oneMonthLater,
      });
      await newUser.save();

      // return user + tempPassword
      return {
        user: newUser,
        tempPassword: generatedPassword,
      };
    },

    // 유저 로그인 -> accessToken + refreshToken
    userLogin: async (_, { loginId, password, phoneNumber }) => {
      if (!loginId || !phoneNumber || !password) {
        throw new UserInputError('loginId, phoneNumber, password는 필수 입력입니다.');
      }

      // 유저 조회
      const user = await User.findOne({ loginId, phoneNumber });
      if (!user) {
        throw new UserInputError('사용자를 찾을 수 없습니다.');
      }

      // validUntil 체크
      if (user.validUntil && user.validUntil < new Date()) {
        throw new ForbiddenError('해당 계정의 유효 기간이 만료되었습니다.');
      }

      // 비밀번호 확인
      const isMatch = await bcrypt.compare(password, user.password);
      if (!isMatch) {
        throw new UserInputError('비밀번호가 올바르지 않습니다.');
      }

      // Access Token + Refresh Token 발급
      const accessToken = generateAccessToken({ userId: user._id });
      const refreshToken = generateRefreshToken({ userId: user._id });

      // DB에 refreshToken 저장
      user.refreshToken = refreshToken;
      await user.save();

      return {
        accessToken,
        refreshToken,
      };
    },

    // 유저 비밀번호 변경 (본인)
    userChangePassword: async (_, { oldPassword, newPassword }, { tokenData }) => {
      const user = await checkUserValid(tokenData);

      if (!oldPassword || !newPassword) {
        throw new UserInputError('oldPassword, newPassword는 필수 입력입니다.');
      }

      // 기존 비번 확인
      const isMatch = await bcrypt.compare(oldPassword, user.password);
      if (!isMatch) {
        throw new UserInputError('기존 비밀번호가 틀립니다.');
      }

      const hashedPw = await bcrypt.hash(newPassword, 10);
      user.password = hashedPw;
      await user.save();

      return user;
    },

    // (Admin 전용) 유저 정보 업데이트
    updateUser: async (_, { userId, name, phoneNumber, validUntil, type }, { tokenData }) => {
      checkAdminValid(tokenData);

      const user = await User.findById(userId);
      if (!user) throw new UserInputError('해당 유저가 존재하지 않습니다.');

      if (name !== undefined) user.name = name;
      if (phoneNumber !== undefined) user.phoneNumber = phoneNumber;
      if (type !== undefined) user.type = type;
      if (validUntil !== undefined) {
        user.validUntil = new Date(validUntil);
      }
      await user.save();
      return user;
    },

    // (Admin 전용) 특정 유저의 비밀번호 리셋
    resetUserPassword: async (_, { userId }, { tokenData }) => {
      checkAdminValid(tokenData);

      const user = await User.findById(userId);
      if (!user) throw new UserInputError('해당 유저가 존재하지 않습니다.');

      const random6 = () => Math.floor(100000 + Math.random() * 900000).toString();
      const newTempPass = random6();
      user.password = await bcrypt.hash(newTempPass, 10);
      await user.save();

      return newTempPass; // 임시 비번 반환
    },

    /* =========================
       토큰 재발급
    ========================= */
    refreshToken: async (_, { refreshToken }) => {
      if (!refreshToken) {
        throw new UserInputError('refreshToken이 필요합니다.');
      }
      const decoded = verifyRefreshToken(refreshToken);
      if (!decoded) {
        throw new ForbiddenError('리프레시 토큰이 유효하지 않습니다.');
      }

      let entity = null;
      let isAdmin = false;

      if (decoded.adminId) {
        // Admin
        entity = await Admin.findById(decoded.adminId);
        isAdmin = true;
      } else if (decoded.userId) {
        // User
        entity = await User.findById(decoded.userId);
      }

      if (!entity) {
        throw new ForbiddenError('토큰의 소유자가 존재하지 않습니다.');
      }

      // DB에 저장된 refreshToken과 일치하는지
      if (entity.refreshToken !== refreshToken) {
        throw new ForbiddenError('이미 사용되었거나 무효화된 토큰입니다.');
      }

      // 유저면 validUntil 체크
      if (!isAdmin && entity.validUntil && entity.validUntil < new Date()) {
        throw new ForbiddenError('유효 기간이 만료된 계정입니다.');
      }

      // 새 Access Token 발급
      let accessPayload = {};
      if (isAdmin) {
        accessPayload = { adminId: entity._id };
      } else {
        accessPayload = { userId: entity._id };
      }

      const newAccessToken = generateAccessToken(accessPayload);

      return {
        accessToken: newAccessToken,
        refreshToken, // 기존 그대로 사용
      };
    },

    /* =========================
       전화번호부 관련
    ========================= */

    // 유저가 여러 개 전화번호부 업로드
    uploadPhoneRecords: async (_, { records }, { tokenData }) => {
      const user = await checkUserValid(tokenData);

      if (!records || !Array.isArray(records) || records.length === 0) {
        throw new UserInputError('records 배열이 비어 있습니다.');
      }

      for (const record of records) {
        const { phoneNumber, name, memo } = record;

        // 1) 기본 체크
        if (!phoneNumber || phoneNumber.trim() === '') {
          // phoneNumber가 없으면 무시 or 에러 처리
          // throw new UserInputError('phoneNumber가 비어 있습니다.');
          continue; // 여기서는 그냥 무시
        }

        let phoneDoc = await PhoneNumber.findOne({ phoneNumber });
        if (!phoneDoc) {
          phoneDoc = new PhoneNumber({
            phoneNumber,
            type: 0,
            records: [],
          });
        }

        // userId가 이미 있는지 확인
        const existingRecord = phoneDoc.records.find(
          (r) => r.userId.toString() === user._id.toString()
        );

        if (existingRecord) {
          // 이미 업로드된 적이 있다면, 동일 여부 체크
          const isSameName = existingRecord.name === (name || '');
          const isSameMemo = existingRecord.memo === (memo || '');
          if (isSameName && isSameMemo) {
            // 완전히 동일하면 넘어감
            continue;
          } else {
            // 기존 record 업데이트
            existingRecord.name = name || '';
            existingRecord.memo = memo || '';
            existingRecord.createdAt = new Date();
          }
        } else {
          // 새로 추가
          phoneDoc.records.push({
            userId: user._id,
            name: name || '',
            memo: memo || '',
            createdAt: new Date(),
          });
        }

        await phoneDoc.save();
      }

      return true;
    },

    // 전화번호 메모 수정 (해당 유저가 업로드한 record만)
    updatePhoneRecordMemo: async (_, { phoneNumber, memo }, { tokenData }) => {
      const user = await checkUserValid(tokenData);

      if (!phoneNumber || phoneNumber.trim() === '') {
        throw new UserInputError('phoneNumber가 비어 있습니다.');
      }

      const phoneDoc = await PhoneNumber.findOne({ phoneNumber });
      if (!phoneDoc) {
        throw new UserInputError('해당 전화번호가 존재하지 않습니다.');
      }

      let foundRecord = null;
      phoneDoc.records.forEach((record) => {
        if (record.userId.toString() === user._id.toString()) {
          foundRecord = record;
        }
      });

      if (!foundRecord) {
        throw new ForbiddenError('본인이 업로드한 기록이 없습니다.');
      }

      // 메모 동일하면 그냥 넘길지, 에러로 할지 결정
      if (foundRecord.memo === memo) {
        // 여기서는 "변경 없음"이라고 에러대신 그냥 true 반환
        // throw new UserInputError('동일한 메모로 변경할 수 없습니다.');
        return true;
      }

      foundRecord.memo = memo;
      foundRecord.createdAt = new Date();
      await phoneDoc.save();
      return true;
    },
  },
};

module.exports = resolvers;
