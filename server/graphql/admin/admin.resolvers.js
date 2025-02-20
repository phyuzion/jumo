// graphql/admin/admin.resolvers.js

const bcrypt = require('bcrypt');
const { UserInputError } = require('apollo-server-errors');

const Admin = require('../../models/Admin');

const User = require('../../models/User');
const PhoneNumber = require('../../models/PhoneNumber');

// JWT 관련: 실제로는 helpers에 두고 import 할 수도 있음
const jwt = require('jsonwebtoken');
const SECRET_KEY = process.env.JWT_SECRET || 'someRandomSecretKey';

function generateAccessToken(payload) {
  return jwt.sign(payload, SECRET_KEY, { expiresIn: '1h' });
}
function generateRefreshToken(payload) {
  return jwt.sign(payload, SECRET_KEY, { expiresIn: '7d' });
}

module.exports = {
  Mutation: {
    // Admin 생성
    createAdmin: async (_, { username, password }) => {
      if (!username || !password) {
        throw new UserInputError('username과 password는 필수 입력입니다.');
      }
      const hashedPw = await bcrypt.hash(password, 10);
      const admin = new Admin({ username, password: hashedPw });
      await admin.save();
      return admin;
    },

    // Admin 로그인
    adminLogin: async (_, { username, password }) => {
      const admin = await Admin.findOne({ username });
      if (!admin) {
        throw new UserInputError('존재하지 않는 Admin입니다.');
      }
      const isMatch = await bcrypt.compare(password, admin.password);
      if (!isMatch) {
        throw new UserInputError('비밀번호가 올바르지 않습니다.');
      }

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
  },


 Query: {
    getSummary: async (_, __, { tokenData }) => {
      // 관리자 권한 체크
      if (!tokenData?.adminId) {
        throw new ForbiddenError('관리자 권한이 필요합니다.');
      }
        // 1) 유저 수
      const usersCount = await User.countDocuments({});
      // 2) 전화번호 문서 수
      const phoneCount = await PhoneNumber.countDocuments({});
      // 3) 위험 번호(type=99) 문서 수
      const dangerPhoneCount = await PhoneNumber.countDocuments({ type: 99 });
        return {
        usersCount,
        phoneCount,
        dangerPhoneCount,
      };
    },
  },
};
