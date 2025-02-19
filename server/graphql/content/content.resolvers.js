// graphql/content/content.resolvers.js

const { UserInputError, AuthenticationError, ForbiddenError } = require('apollo-server-errors');
const Content = require('../../models/Content');
const User = require('../../models/User');

// 유저 체크
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

// 작성자 or 관리자 체크
async function checkAuthorOrAdmin(tokenData, content) {
  if (tokenData?.adminId) {
    // 관리자면 OK
    return;
  }
  if (tokenData?.userId?.toString() !== content.userId.toString()) {
    throw new ForbiddenError('수정/삭제 권한이 없습니다.');
  }
}

module.exports = {
  Query: {
    getContents: async (_, { type }) => {
      // 로그인 필요없이도 볼 수 있는지, 정책에 따라 다름
      // 예시: 모든 유저(로그인 안 해도) 볼 수 있다고 가정
      const filter = {};
      if (type !== undefined) {
        filter.type = type;
      }
      return Content.find(filter).sort({ createdAt: -1 }); 
    },

    getSingleContent: async (_, { contentId }) => {
      const content = await Content.findById(contentId);
      if (!content) {
        throw new UserInputError('해당 글을 찾을 수 없습니다.');
      }
      return content;
    },
  },

  Mutation: {
    createContent: async (_, { type, title, content }, { tokenData }) => {
      const user = await checkUserValid(tokenData);
      if (!content) {
        throw new UserInputError('content는 필수입니다.');
      }

      const newContent = new Content({
        userId: user._id,
        type: type || 0,
        title: title || '',
        content, // Quill Delta (문자열)
        createdAt: new Date(),
        comments: [],
      });

      await newContent.save();
      return newContent;
    },

    updateContent: async (_, { contentId, title, content }, { tokenData }) => {
      const user = await checkUserValid(tokenData);

      const found = await Content.findById(contentId);
      if (!found) {
        throw new UserInputError('수정할 글이 없습니다.');
      }

      await checkAuthorOrAdmin(tokenData, found);

      if (title !== undefined) found.title = title;
      if (content !== undefined) found.content = content;
      await found.save();
      return found;
    },

    deleteContent: async (_, { contentId }, { tokenData }) => {
      const user = await checkUserValid(tokenData);

      const found = await Content.findById(contentId);
      if (!found) {
        throw new UserInputError('삭제할 글이 없습니다.');
      }

      await checkAuthorOrAdmin(tokenData, found);

      await Content.deleteOne({ _id: contentId });
      return true;
    },

    // 댓글 생성
    createReply: async (_, { contentId, comment }, { tokenData }) => {
      const user = await checkUserValid(tokenData);

      const found = await Content.findById(contentId);
      if (!found) {
        throw new UserInputError('글이 존재하지 않습니다.');
      }

      // 댓글 작성
      found.comments.push({
        userId: user._id,
        comment,
        createdAt: new Date(),
      });

      await found.save();
      return found;
    },

    // 댓글 삭제 (index 기반)
    deleteReply: async (_, { contentId, index }, { tokenData }) => {
      const user = await checkUserValid(tokenData);

      const found = await Content.findById(contentId);
      if (!found) {
        throw new UserInputError('글이 존재하지 않습니다.');
      }

      // 댓글이 범위를 벗어나면 에러
      if (index < 0 || index >= found.comments.length) {
        throw new UserInputError('해당 댓글이 존재하지 않습니다.');
      }

      // 작성자나 admin인지 확인
      const commentObj = found.comments[index];
      if (tokenData.adminId?.toString()) {
        // admin ok
      } else if (commentObj.userId.toString() !== tokenData.userId.toString()) {
        throw new ForbiddenError('댓글 삭제 권한이 없습니다.');
      }

      // 삭제
      found.comments.splice(index, 1);

      await found.save();
      return true;
    },
  },
};
