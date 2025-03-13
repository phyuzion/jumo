// models/Version.js
const mongoose = require('mongoose');

const versionSchema = new mongoose.Schema({
  version: { type: String, default: '1.0.0' },
  // 필요하다면 파일명, 경로, 기타 정보 등도 추가 가능
  createdAt: { type: Date, default: Date.now },
});

module.exports = mongoose.model('Version', versionSchema);
