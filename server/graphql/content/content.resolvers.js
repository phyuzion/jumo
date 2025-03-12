const { UserInputError, AuthenticationError, ForbiddenError } = require('apollo-server-errors');
const { GraphQLJSON } = require('graphql-type-json');
const Content = require('../../models/Content');
const User = require('../../models/User');
const Admin = require('../../models/Admin');

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
    return; // admin
  }
  if (!tokenData?.userId) {
    throw new ForbiddenError('권한이 없습니다.(로그인 필요)');
  }

  // content.user == null => admin 작성 => 일반유저 권한 없음
  if (!content.user) {
    throw new ForbiddenError('관리자 작성글은 일반 유저가 수정할 수 없습니다.');
  }
  // 아니면 본인 체크
  if (String(content.user) !== String(tokenData.userId)) {
    throw new ForbiddenError('수정/삭제 권한이 없습니다.');
  }
}

module.exports = {
  JSON: GraphQLJSON,

  Query: {
    /** ========== getContents ========== */
    getContents: async (_, { type }, { tokenData }) => {
      const filter = {};
      if (type !== undefined) filter.type = type;

      // populate는 user.name 만 필요(아래서 phoneNumber 등 필요 없으니)
      const docs = await Content.find(filter)
        .populate('user', 'name') // user=null(어드민)이면 populate 무시
        .select('_id user type title createdAt')
        .sort({ createdAt: -1 });

      // content, comments 생략
      // userName만 매핑
      return docs.map(doc => {
        let userName = 'admin';
        if (doc.user) {
          userName = doc.user.name || '(NoName)';
        }

        return {
          id: doc._id,
          userName,
          type: doc.type,
          title: doc.title,
          createdAt: doc.createdAt,
          content: {},    // 빈 객체
          comments: [],   // 빈 배열
        };
      });
    },

    /** ========== getSingleContent ========== */
    getSingleContent: async (_, { contentId }, { tokenData }) => {
      const doc = await Content.findById(contentId)
        .populate('user', 'name')             // 글 작성자 user
        .populate('comments.user', 'name');   // 댓글 user

      if (!doc) throw new UserInputError('해당 글 없음');

      // 여기서 userName/comment.userName을 만들어서 리턴
      // doc 자체는 Mongoose document (user=UserDoc or null)
      // comments[].user=UserDoc or null
      // => hand-map => { id, userName, ... , comments: [ {userName, ...}, ... ] }
      
      let contentUserName = 'admin';
      if (doc.user) {
        contentUserName = doc.user.name || '(NoName)';
      }

      // 댓글
      const mappedComments = doc.comments.map(c => {
        let cUserName = 'admin';
        if (c.user) {
          cUserName = c.user.name || '(NoName)';
        }
        return {
          userName: cUserName,
          comment: c.comment,
          createdAt: c.createdAt,
        };
      });

      return {
        id: doc._id,
        userName: contentUserName,
        type: doc.type,
        title: doc.title,
        createdAt: doc.createdAt,
        content: doc.content,
        comments: mappedComments,
      };
    },
  },

  Mutation: {
    /** ========== createContent ========== */
    createContent: async (_, { type, title, content }, { tokenData }) => {
      let userId = null;
      if (tokenData?.adminId) {
        // admin -> user=null
        const adminFound = await Admin.findById(tokenData.adminId);
        if (!adminFound) {
          throw new UserInputError('Admin not found');
        }
      } else {
        // 일반 유저
        const userDoc = await checkUserValid(tokenData);
        userId = userDoc._id;
      }

      const newDoc = new Content({
        user: userId,  // null if admin
        type: type || 0,
        title: title || '',
        content,
        createdAt: new Date(),
        comments: [],
      });
      await newDoc.save();

      // populate => user.name
      const populated = await newDoc
        .populate('user', 'name')
        .execPopulate();

      // 반환 시 userName으로 매핑
      let contentUserName = 'admin';
      if (populated.user) {
        contentUserName = populated.user.name || '(NoName)';
      }

      // 댓글은 아직 empty
      return {
        id: populated._id,
        userName: contentUserName,
        type: populated.type,
        title: populated.title,
        createdAt: populated.createdAt,
        content: populated.content,
        comments: [],
      };
    },

    /** ========== updateContent ========== */
    updateContent: async (_, { contentId, title, content, type }, { tokenData }) => {
      const doc = await Content.findById(contentId);
      if (!doc) throw new UserInputError('글 없음');

      await checkAuthorOrAdmin(tokenData, doc);

      if (title !== undefined) doc.title = title;
      if (type !== undefined) doc.type = type;
      if (content !== undefined) doc.content = content;

      await doc.save();

      // populate
      const populated = await doc
        .populate('user', 'name')
        .populate('comments.user', 'name')
        .execPopulate();

      // userName, comments[].userName
      let contentUserName = 'admin';
      if (populated.user) {
        contentUserName = populated.user.name || '(NoName)';
      }
      const mappedComments = populated.comments.map(c => {
        let cUserName = 'admin';
        if (c.user) cUserName = c.user.name || '(NoName)';
        return {
          userName: cUserName,
          comment: c.comment,
          createdAt: c.createdAt,
        };
      });

      return {
        id: populated._id,
        userName: contentUserName,
        type: populated.type,
        title: populated.title,
        createdAt: populated.createdAt,
        content: populated.content,
        comments: mappedComments,
      };
    },

    /** ========== deleteContent ========== */
    deleteContent: async (_, { contentId }, { tokenData }) => {
      const found = await Content.findById(contentId);
      if (!found) {
        throw new UserInputError('삭제할 글이 없습니다.');
      }
      await checkAuthorOrAdmin(tokenData, found);

      await Content.deleteOne({ _id: contentId });
      return true;
    },

    /** ========== createReply ========== */
    createReply: async (_, { contentId, comment }, { tokenData }) => {
      const found = await Content.findById(contentId);
      if (!found) {
        throw new UserInputError('글이 존재하지 않습니다.');
      }

      let userId = null;
      if (tokenData?.adminId) {
        const adminFound = await Admin.findById(tokenData.adminId);
        if (!adminFound) {
          throw new UserInputError('admin user not found');
        }
        // => user=null
      } else {
        const userDoc = await checkUserValid(tokenData);
        userId = userDoc._id;
      }

      found.comments.push({
        user: userId,
        comment,
        createdAt: new Date(),
      });

      await found.save();

      // populate
      const populated = await found
        .populate('user', 'name')
        .populate('comments.user', 'name')
        .execPopulate();

      // map userName
      let contentUserName = 'admin';
      if (populated.user) {
        contentUserName = populated.user.name || '(NoName)';
      }
      const mappedComments = populated.comments.map(c => {
        let cUserName = 'admin';
        if (c.user) cUserName = c.user.name || '(NoName)';
        return {
          userName: cUserName,
          comment: c.comment,
          createdAt: c.createdAt,
        };
      });

      return {
        id: populated._id,
        userName: contentUserName,
        type: populated.type,
        title: populated.title,
        createdAt: populated.createdAt,
        content: populated.content,
        comments: mappedComments,
      };
    },

    /** ========== deleteReply ========== */
    deleteReply: async (_, { contentId, index }, { tokenData }) => {
      const doc = await Content.findById(contentId);
      if (!doc) throw new UserInputError('글 없음');

      if (index < 0 || index >= doc.comments.length) {
        throw new UserInputError('해당 댓글 없음');
      }
      const cObj = doc.comments[index];

      if (tokenData?.adminId) {
        // admin => pass
      } else {
        const user = await checkUserValid(tokenData);
        // if cObj.user=null => admin => 일반유저 불가
        if (!cObj.user) {
          throw new ForbiddenError('관리자 댓글은 일반유저가 삭제 불가');
        }
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
