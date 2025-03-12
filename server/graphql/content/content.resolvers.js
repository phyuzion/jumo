const { UserInputError, AuthenticationError, ForbiddenError } = require('apollo-server-errors');
const { GraphQLJSON } = require('graphql-type-json');
const Content = require('../../models/Content');
const User = require('../../models/User');

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
  if (tokenData?.adminId) {
    return;
  }
  if (!tokenData?.userId) {
    throw new ForbiddenError('권한이 없습니다.(로그인 필요)');
  }
  // content.user 는 ObjectId
  if (String(content.user) !== String(tokenData.userId)) {
    throw new ForbiddenError('수정/삭제 권한이 없습니다.');
  }
}

module.exports = {
  JSON: GraphQLJSON,

  Query: {
    getContents: async (_, { type }, { tokenData }) => {
      const filter = {};
      if (type !== undefined) filter.type = type;

      // admin이면 user: 'name phoneNumber region'
      // 아니면 'name region' 정도만
      // (region 굳이 빼도 됩니다.)
      let userSelect = 'name region';
      if (tokenData?.adminId) {
        userSelect = 'name region phoneNumber'; 
      }

      const docs = await Content.find(filter)
        .populate('user', userSelect)
        .select('_id user type title createdAt')
        .sort({ createdAt: -1 });

      // content, comments 생략
      return docs.map(doc => {
        // doc.user는 { _id, name, region, phoneNumber? }
        return {
          id: doc._id,
          user: doc.user,
          type: doc.type,
          title: doc.title,
          createdAt: doc.createdAt,
          content: {},
          comments: [],
        };
      });
    },

    getSingleContent: async (_, { contentId }, { tokenData }) => {
      let userSelect = 'name region';
      if (tokenData?.adminId) {
        userSelect = 'name region phoneNumber';
      }

      // 댓글 작성자도 같은 select
      const doc = await Content.findById(contentId)
        .populate('user', userSelect)
        .populate('comments.user', userSelect);

      if (!doc) throw new UserInputError('해당 글 없음');
      return doc; 
    },
  },

  Mutation: {
    createContent: async (_, { type, title, content }, { tokenData }) => {
      let userId;
      if (tokenData?.adminId) {
        // 관리자도 User 컬렉션 문서가 있다면
        userId = tokenData.adminId;
      } else {
        const user = await checkUserValid(tokenData);
        userId = user._id;
      }

      const newDoc = new Content({
        user: userId,
        type: type || 0,
        title: title || '',
        content: content,
        createdAt: new Date(),
        comments: [],
      });
      await newDoc.save();

      // populate 해서 반환
      return newDoc
        .populate('user', 'name region phoneNumber')
        .execPopulate();
    },

    updateContent: async (_, { contentId, title, content, type }, { tokenData }) => {
      const doc = await Content.findById(contentId);
      if (!doc) throw new UserInputError('글 없음');

      await checkAuthorOrAdmin(tokenData, doc);

      if (title !== undefined) doc.title = title;
      if (type !== undefined) doc.type = type;
      if (content !== undefined) doc.content = content;

      await doc.save();

      // populate
      return doc
        .populate('user', 'name region phoneNumber')
        .populate('comments.user', 'name region phoneNumber')
        .execPopulate();
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
      let userDoc;
      if (tokenData?.adminId) {
        userDoc = await User.findById(tokenData.adminId);
        if (!userDoc) {
          throw new UserInputError('admin user not found');
        }
      } else {
        userDoc = await checkUserValid(tokenData);
      }

      const found = await Content.findById(contentId);
      if (!found) throw new UserInputError('글이 존재하지 않습니다.');

      found.comments.push({
        user: userDoc._id,
        comment,
        createdAt: new Date(),
      });

      await found.save();

      return found
        .populate('user', 'name region phoneNumber')
        .populate('comments.user', 'name region phoneNumber')
        .execPopulate();
    },

    // 댓글 삭제
    deleteReply: async (_, { contentId, index }, { tokenData }) => {
      const doc = await Content.findById(contentId);
      if (!doc) throw new UserInputError('글 없음');

      if (index < 0 || index >= doc.comments.length) {
        throw new UserInputError('해당 댓글 없음');
      }
      const cObj = doc.comments[index];

      // admin or same user
      if (!tokenData?.adminId) {
        const user = await checkUserValid(tokenData);
        if (String(cObj.user) !== String(user._id)) {
          throw new ForbiddenError('댓글 삭제 권한 없음');
        }
      }
      doc.comments.splice(index, 1);
      await doc.save();

      return true;
    },
  },
};
