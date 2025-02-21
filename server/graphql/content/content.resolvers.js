// graphql/content/content.resolvers.js
const { UserInputError, AuthenticationError, ForbiddenError } = require('apollo-server-errors');
const { GraphQLJSON } = require('graphql-type-json'); // 추가
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
  JSON: GraphQLJSON,

  Query: {
    getContents: async (_, { type }) => {
      // 부분 필드만 가져오기
      const filter = {};
      if (type !== undefined) filter.type = type;
      const docs = await Content.find(filter)
        .select('_id userId type title createdAt')
        .sort({ createdAt: -1 });

      // content, comments 생략 => 빈 값
      return docs.map(doc => ({
        id: doc._id,
        userId: doc.userId, // string
        type: doc.type,
        title: doc.title,
        createdAt: doc.createdAt,
        content: {}, // empty object
        comments: [],
      }));
    },
    getSingleContent: async (_, { contentId }) => {
      const doc = await Content.findById(contentId);
      if (!doc) throw new UserInputError('해당 글 없음');
      return doc; // doc.content는 Mixed(JSON)
    },
  },

  Mutation: {
    createContent: async (_, { type, title, content }, { tokenData }) => {
      // content는 이미 JSON 형태로 GraphQL이 파싱해 줌!
      // 관리자 or 유저
      let userIdStr = '';
      if (tokenData?.adminId) {
        userIdStr = 'admin';
      } else {
        const user = await checkUserValid(tokenData);
        userIdStr = user._id.toString();
      }

      const newDoc = new Content({
        userId: userIdStr,
        type: type || 0,
        title: title || '',
        content: content, // 그대로 JSON 객체
        createdAt: new Date(),
        comments: [],
      });
      await newDoc.save();
      return newDoc;
    },

    updateContent: async (_, { contentId, title, content, type }, { tokenData }) => {
      const doc = await Content.findById(contentId);
      if (!doc) throw new UserInputError('글 없음');
      await checkAuthorOrAdmin(tokenData, doc);

      if (title !== undefined) doc.title = title;
      if (type !== undefined) doc.type = type;
      if (content !== undefined) {
        // content는 이미 JSON 객체
        doc.content = content;
      }
      await doc.save();
      return doc;
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

      // 관리자 or 유저
      let userIdStr = '';
      if (tokenData?.adminId) {
        userIdStr = 'admin';
      } else {
        const user = await checkUserValid(tokenData);
        userIdStr = user._id.toString();
      }

      const found = await Content.findById(contentId);
      if (!found) {
        throw new UserInputError('글이 존재하지 않습니다.');
      }

      // 댓글 작성
      found.comments.push({
        userId: userIdStr, 
        comment,
        createdAt: new Date(),
      });

      await found.save();
      return found;
    },

    // 댓글 삭제(index)
    deleteReply: async (_, { contentId, index }, { tokenData }) => {
      const doc = await Content.findById(contentId);
      if (!doc) throw new UserInputError('글 없음');
      if (index < 0 || index >= doc.comments.length) {
        throw new UserInputError('해당 댓글 없음');
      }
      const cObj = doc.comments[index];
      // admin or same user
      if (tokenData?.adminId) {
        // pass
      } else {
        const user = await checkUserValid(tokenData);
        if (cObj.userId !== user._id.toString()) {
          throw new ForbiddenError('댓글 삭제 권한 없음');
        }
      }
      doc.comments.splice(index, 1);
      await doc.save();
      return true;
    },
  },
};
