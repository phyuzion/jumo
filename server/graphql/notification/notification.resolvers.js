// graphql/notification/notification.resolvers.js
const { ForbiddenError } = require('apollo-server-errors');
const Notification = require('../../models/Notification');

module.exports = {
  Query: {
    getNotifications: async (_, __, { tokenData }) => {
      // 로그인 필요여부는 정책에 따라
      // if (!tokenData?.userId) { throw new AuthenticationError('로그인 필수'); }

      const now = new Date();
      return Notification.find({ validUntil: { $gt: now } }).sort({ createdAt: -1 });
    },
  },
  Mutation: {
    createNotification: async (_, { title, message, validUntil }, { tokenData }) => {
      // 어드민 체크
      if (!tokenData?.adminId) {
        throw new ForbiddenError('관리자 권한이 필요합니다.');
      }

      const noti = new Notification({
        title,
        message,
        validUntil: validUntil ? new Date(validUntil) : new Date(Date.now() + 24*60*60*1000), // default 1일
      });
      await noti.save();
      return noti;
    },
  },
};
