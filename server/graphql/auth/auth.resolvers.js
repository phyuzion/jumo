// graphql/auth/auth.resolvers.js

const { ForbiddenError } = require('apollo-server-errors');

const Admin = require('../../models/Admin');
const User = require('../../models/User');

const {
  verifyRefreshToken,
  generateAccessToken,
  generateRefreshToken
} = require('./utils');

module.exports = {
  Mutation: {
    /*
      refreshToken(refreshToken: String!): AuthPayload
      - Refresh Token 검증 -> DB에서 존재/유효성 확인 -> 새 Access/Refresh 발급
    */
    refreshToken: async (_, { refreshToken }) => {
      // 1) Refresh Token 검증
      const decoded = verifyRefreshToken(refreshToken);
      if (!decoded) {
        throw new ForbiddenError('리프레시 토큰이 만료되었거나 유효하지 않습니다.');
      }

      // 2) Admin / User 구분
      let entity = null;
      let isAdmin = false;

      if (decoded.adminId) {
        entity = await Admin.findById(decoded.adminId);
        isAdmin = true;
      } else if (decoded.userId) {
        entity = await User.findById(decoded.userId);
      }

      if (!entity) {
        throw new ForbiddenError('토큰의 소유자가 존재하지 않습니다.');
      }

      // 3) DB에 저장된 refreshToken과 비교
      if (entity.refreshToken !== refreshToken) {
        throw new ForbiddenError('이미 사용되었거나 무효화된 토큰입니다.');
      }

      // 4) 새 Access Token 생성 (유저 or 어드민)
      let newPayload = {};
      if (isAdmin) {
        newPayload = { adminId: entity._id };
      } else {
        newPayload = { userId: entity._id };
      }

      const newAccess = generateAccessToken(newPayload);
      // 새 Refresh Token도 발급
      const newRefresh = generateRefreshToken(newPayload);

      // 5) DB에 새 refreshToken 저장
      entity.refreshToken = newRefresh;
      await entity.save();

      // 6) 반환
      return {
        accessToken: newAccess,
        refreshToken: newRefresh,
      };
    },
  },
};
