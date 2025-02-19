// models/Content.js
const mongoose = require('mongoose');

const commentSchema = new mongoose.Schema({
  userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
  comment: { type: String }, // 댓글 내용 (여기도 Quill Delta로 저장할 수도 있지만, 일반 텍스트가 일반적)
  createdAt: { type: Date, default: Date.now },
});

const contentSchema = new mongoose.Schema({
  userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
  type: { type: Number, default: 0 }, // 게시판 카테고리 등
  title: { type: String, default: '' },
  content: { type: String, default: '' }, // Quill Delta(JSON.stringify) 보관
  createdAt: { type: Date, default: Date.now },
  comments: [commentSchema],
});

module.exports = mongoose.model('Content', contentSchema);
