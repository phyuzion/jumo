// graphql/content/content.resolvers.js
const {
  UserInputError,
  AuthenticationError,
  ForbiddenError,
} = require('apollo-server-errors');
const { GraphQLJSON } = require('graphql-type-json');
const Content = require('../../models/Content');
const User = require('../../models/User');

const { checkUserValid, checkAdminValid, checkAuthorOrAdmin, checkUserOrAdmin } = require('../auth/utils');
const path = require('path');
const fs = require('fs');
const { v4: uuidv4 } = require('uuid');


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
        type: type || '',
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

      // 권한 체크
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

    uploadContentImage: async (_, { file }, { tokenData }) => {
      // 권한 체크
      checkUserOrAdmin(tokenData);

      console.log("==== [uploadContentImage] START ====");
      console.log("file argument =", file);

      // 1) await file
      const upload = await file;
      // 2) destruct from upload.file
      const { filename, mimetype, encoding, createReadStream } = upload.file;

      console.log("filename =", filename);
      console.log("mimetype =", mimetype);
      console.log("encoding =", encoding);
      console.log("createReadStream =", createReadStream);

      if (!createReadStream) {
        throw new Error("createReadStream is missing");
      }

      // 이미지 저장 경로
      const imgPath = '/var/data/contents/images';

      // 디렉토리가 없으면 생성
      if (!fs.existsSync(imgPath)) {
        fs.mkdirSync(imgPath, { recursive: true });
      }

      // 파일 확장자 추출
      const ext = path.extname(filename);
      
      // UUID로 새 파일명 생성
      const newFilename = `${uuidv4()}${ext}`;
      const filepath = path.join(imgPath, newFilename);

      return new Promise((resolve, reject) => {
        const readStream = createReadStream();
        const writeStream = fs.createWriteStream(filepath);

        readStream
          .pipe(writeStream)
          .on('finish', () => {
            console.log(`✅ Image file saved at: ${filepath}`);
            resolve(`/contents/images/${newFilename}`);
          })
          .on('error', (err) => {
            console.error('File upload error:', err);
            reject(err);
          });
      });
    },
  },
};
