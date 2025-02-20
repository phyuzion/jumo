// graphql/content/content.resolvers.js
const { UserInputError, AuthenticationError, ForbiddenError } = require('apollo-server-errors');
const Content = require('../../models/Content');
const User = require('../../models/User');

// 체크 함수들
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

// 작성자 or 관리자
async function checkAuthorOrAdmin(tokenData, content) {
  // 관리자면 바로 ok
  if (tokenData?.adminId) {
    return; 
  }
  // 일반유저
  if (!tokenData?.userId) {
    throw new ForbiddenError('권한이 없습니다.(로그인 필요)');
  }
  // content.userId: 글 작성자
  if (content.userId.toString() !== tokenData.userId.toString()) {
    throw new ForbiddenError('수정/삭제 권한이 없습니다.');
  }
}

module.exports = {
  Query: {
    // 목록(부분 필드)
    getContents: async (_, { type }) => {
      const filter = {};
      if (type !== undefined) {
        filter.type = type;
      }
      const contents = await Content.find(filter)
        .select('_id userId type title createdAt')
        .sort({ createdAt: -1 });
      // GraphQL: id, userId, type, title, createdAt, content="", comments=[]
      return contents.map(doc => ({
        id: doc._id,
        userId: doc.userId,
        type: doc.type,
        title: doc.title,
        createdAt: doc.createdAt,
        content: '',
        comments: [],
      }));
    },

    // 상세
    getSingleContent: async (_, { contentId }) => {
      const content = await Content.findById(contentId);
      if (!content) {
        throw new UserInputError('해당 글을 찾을 수 없습니다.');
      }
      // 그대로 반환 (content, comments 전부)
      return content;
    },
  },

  Mutation: {
    // 글 생성
    createContent: async (_, { type, title, content }, { tokenData }) => {
      // 관리자 or 유저 구분
      let userIdForThis = null;
      if (tokenData?.adminId) {
        // admin
        userIdForThis = 'admin'; // 문자열 표시 or tokenData.adminId
      } else {
        // 일반 유저 -> checkUserValid
        const user = await checkUserValid(tokenData);
        userIdForThis = user._id; 
      }

      if (!content) {
        throw new UserInputError('content는 필수입니다.');
      }

      const newDoc = new Content({
        userId: userIdForThis,
        type: type || 0,
        title: title || '',
        content,
        createdAt: new Date(),
        comments: [],
      });
      await newDoc.save();
      return newDoc;
    },

    // 글 수정
    updateContent: async (_, { contentId, title, content, type }, { tokenData }) => {
      // 글 찾기
      const found = await Content.findById(contentId);
      if (!found) {
        throw new UserInputError('수정할 글이 없습니다.');
      }
      // 작성자 or admin
      await checkAuthorOrAdmin(tokenData, found);

      if (title !== undefined) found.title = title;
      if (content !== undefined) found.content = content;
      if (type !== undefined) found.type = type; // admin or author
      await found.save();
      return found;
    },

    // 글 삭제
    deleteContent: async (_, { contentId }, { tokenData }) => {
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
      // 로그인 유저 필요
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

    // 댓글 삭제(index)
    deleteReply: async (_, { contentId, index }, { tokenData }) => {
      const user = await checkUserValid(tokenData);

      const found = await Content.findById(contentId);
      if (!found) {
        throw new UserInputError('글이 존재하지 않습니다.');
      }
      if (index < 0 || index >= found.comments.length) {
        throw new UserInputError('해당 댓글이 존재하지 않습니다.');
      }

      // 댓글 작성자 or admin
      const commentObj = found.comments[index];
      if (tokenData?.adminId) {
        // admin ok
      } else if (commentObj.userId.toString() !== user._id.toString()) {
        throw new ForbiddenError('댓글 삭제 권한이 없습니다.');
      }

      found.comments.splice(index, 1);
      await found.save();
      return true;
    },
  },
};
