// models/Content.js
const mongoose = require('mongoose');

const commentSchema = new mongoose.Schema({
  userId: { type: String },
  comment: { type: String }, // 댓글 내용 (여기도 Quill Delta로 저장할 수도 있지만, 일반 텍스트가 일반적)
  createdAt: { type: Date, default: Date.now },
});

const contentSchema = new mongoose.Schema({
  userId: { type: String },
  type: { type: Number, default: 0 }, // 게시판 카테고리 등
  title: { type: String, default: '' },
  content: { type: mongoose.Schema.Types.Mixed, default: {} },
  createdAt: { type: Date, default: Date.now },
  comments: [commentSchema],
});

module.exports = mongoose.model('Content', contentSchema);
