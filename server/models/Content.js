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
  type: { type: Number, default: 0 },
  title: { type: String, default: '' },
  content: { type: mongoose.Schema.Types.Mixed, default: {} },
  createdAt: { type: Date, default: Date.now },
  comments: [commentSchema],
});

module.exports = mongoose.model('Content', contentSchema);
