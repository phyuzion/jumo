// graphql/notification/notification.resolvers.js
const { ForbiddenError, AuthenticationError } = require('apollo-server-errors');
const Notification = require('../../models/Notification');
const User = require('../../models/User');
const { checkAdminValid } = require('../auth/utils');

module.exports = {
  Query: {
    getNotifications: async (_, __, { tokenData }) => {
      const now = new Date(); // UTC 시간, DateScalar가 자동 변환

      if (tokenData?.adminId) {
        // 1) 어드민: 만료 여부 상관없이 전체
        return Notification.find({}).sort({ createdAt: -1 });

      } else if (tokenData?.userId) {
        // 2) 일반 유저:
        //    - validUntil > now
        //    - targetUserId = null(전역) or targetUserId = userId
        return Notification.find({
          validUntil: { $gt: now },
          $or: [
            { targetUserId: null },
            { targetUserId: tokenData.userId },
          ],
        }).sort({ createdAt: -1 });

      } else {
        // 3) 비로그인: 전역+유효한 것만
        return Notification.find({
          validUntil: { $gt: now },
          targetUserId: null,
        }).sort({ createdAt: -1 });
      }
    },
  },

  Mutation: {
    createNotification: async (_, { title, message, validUntil, userId }, { tokenData }) => {
      // 어드민 체크
      await checkAdminValid(tokenData);

      let validDate = new Date(Date.now() + 24 * 60 * 60 * 1000); // 기본 1일 (UTC 시간)
      if (validUntil) {
        validDate = new Date(validUntil); // ISO 문자열을 UTC Date로 변환, DateScalar가 KST→UTC 자동 변환
      }

      let targetUser = null;
      if (userId) {
        // userId가 유효한 유저인지 체크(선택사항)
        const user = await User.findById(userId);
        if (!user) {
          throw new AuthenticationError('해당 유저가 존재하지 않습니다.');
        }
        targetUser = userId; // ObjectId
      }

      const noti = new Notification({
        title,
        message,
        validUntil: validDate,
        targetUserId: targetUser,
      });
      await noti.save();
      return noti; // Date 필드는 DateScalar가 UTC→KST 자동 변환
    },
  },
};
