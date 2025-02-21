// models/Notification.js
const mongoose = require('mongoose');

const notificationSchema = new mongoose.Schema({
  title: { type: String, required: true },
  message: { type: String, default: '' },
  validUntil: { type: Date, default: null },
  createdAt: { type: Date, default: Date.now },
  targetUserId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', default: null },
});

module.exports = mongoose.model('Notification', notificationSchema);
