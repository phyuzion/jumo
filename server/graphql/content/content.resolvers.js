// graphql/content/content.resolvers.js
const {
  UserInputError,
  AuthenticationError,
  ForbiddenError,
} = require('apollo-server-errors');
const { GraphQLJSON } = require('graphql-type-json');
const Content = require('../../models/Content');
const User = require('../../models/User');

// 유저 토큰 검증 (일반 유저)
async function checkUserValid(tokenData) {
  if (!tokenData?.userId) {
    throw new AuthenticationError('로그인이 필요합니다.');
  }
  const user = await User.findById(tokenData.userId);
  if (!user) {
    throw new ForbiddenError('유효하지 않은 유저입니다.(checkUserValid)');
  }
  if (user.validUntil && user.validUntil < new Date()) {
    throw new ForbiddenError('유효 기간이 만료된 계정입니다.');
  }
  return user;
}

/*
  작성자 권한 or 관리자 권한 체크
  - 관리자면 바로 OK
  - 일반 유저라면 contentDoc.userId === tokenData.userId 이어야 함
*/
async function checkAuthorOrAdmin(tokenData, contentDoc) {
  if (tokenData?.adminId) {
    return; // 관리자
  }
  if (!tokenData?.userId) {
    throw new ForbiddenError('권한이 없습니다.(로그인 필요)');
  }
  const user = await User.findById(tokenData.userId);
  if (!user) {
    throw new ForbiddenError('유효하지 않은 유저입니다.(checkAuthorOrAdmin)');
  }
  // contentDoc.userId가 로그인 유저의 _id와 같아야 함
  if (contentDoc.userId !== user._id.toString()) {
    throw new ForbiddenError('수정/삭제 권한이 없습니다.');
  }
}

module.exports = {
  JSON: GraphQLJSON,

  Query: {
    getContents: async (_, { type }) => {
      const filter = {};
      if (type !== undefined) filter.type = type;

      const docs = await Content.find(filter)
        .select('_id userId userName userRegion type title createdAt')
        .sort({ createdAt: -1 });

      return docs.map((doc) => ({
        id: doc._id,
        userId: doc.userId,
        userName: doc.userName,
        userRegion: doc.userRegion,
        type: doc.type,
        title: doc.title,
        createdAt: doc.createdAt,
      }));
    },

    getSingleContent: async (_, { contentId }) => {
      const doc = await Content.findById(contentId);
      if (!doc) throw new UserInputError('해당 글 없음');
      return doc;
    },
  },

  Mutation: {
    // 글 생성
    createContent: async (_, { type, title, content }, { tokenData }) => {
      let userId = '';
      let userName = '';
      let userRegion = '';

      if (tokenData?.adminId) {
        // 관리자
        userId = 'admin';
        userName = 'admin';
        userRegion = 'all';
      } else {
        // 일반 유저
        const user = await checkUserValid(tokenData);
        userId = user._id.toString();
        userName = user.name;
        userRegion = user.region || '';
      }

      const newDoc = new Content({
        userId,
        userName,
        userRegion,
        type: type || 0,
        title: title || '',
        content: content,
        createdAt: new Date(),
        comments: [],
      });
      await newDoc.save();
      return newDoc;
    },

    // 글 수정
    updateContent: async (_, { contentId, title, content, type }, { tokenData }) => {
      const doc = await Content.findById(contentId);
      if (!doc) throw new UserInputError('글 없음');

      await checkAuthorOrAdmin(tokenData, doc);

      if (title !== undefined) doc.title = title;
      if (type !== undefined) doc.type = type;
      if (content !== undefined) {
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
      let userId = '';
      let userName = '';
      let userRegion = '';

      if (tokenData?.adminId) {
        userId = 'admin';
        userName = 'admin';
        userRegion = 'all';
      } else {
        const user = await checkUserValid(tokenData);
        userId = user._id.toString();
        userName = user.name;
        userRegion = user.region || '';
      }

      const found = await Content.findById(contentId);
      if (!found) {
        throw new UserInputError('글이 존재하지 않습니다.');
      }

      found.comments.push({
        userId,
        userName,
        userRegion,
        comment,
        createdAt: new Date(),
      });

      await found.save();
      return found;
    },

    // 댓글 삭제(index로 식별)
    deleteReply: async (_, { contentId, index }, { tokenData }) => {
      const doc = await Content.findById(contentId);
      if (!doc) throw new UserInputError('글 없음');
      if (index < 0 || index >= doc.comments.length) {
        throw new UserInputError('해당 댓글 없음');
      }
      const cObj = doc.comments[index];

      if (tokenData?.adminId) {
        // 관리자면 바로 가능
      } else {
        const user = await checkUserValid(tokenData);
        // 댓글 작성자와 현재 로그인 유저가 같은지 체크
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
