// models/Content.js
const mongoose = require('mongoose');

const commentSchema = new mongoose.Schema({
  userId: { type: String },                 
  userName: { type: String, default: '' },  
  userRegion: { type: String, default: '' },
  comment: { type: String },
  createdAt: { type: Date, default: Date.now },
});

const contentSchema = new mongoose.Schema({
  userId: { type: String },  
  userName: { type: String, default: '' }, 
  userRegion: { type: String, default: '' },
  type: { type: String, default: '' },
  title: { type: String, default: '' },
  content: { type: mongoose.Schema.Types.Mixed, default: {} },
  createdAt: { type: Date, default: Date.now },
  comments: [commentSchema],
});

// type과 createdAt에 대한 복합 인덱스 추가
contentSchema.index({ type: 1, createdAt: -1 });

module.exports = mongoose.model('Content', contentSchema);
