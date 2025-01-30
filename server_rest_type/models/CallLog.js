// models/CallLog.js
const mongoose = require('mongoose');

const callLogSchema = new mongoose.Schema({
  customerId: { 
    type: mongoose.Schema.Types.ObjectId, 
    ref: 'Customer', 
    required: true 
  },
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },
  timestamp: { type: Date, default: Date.now },
  score: { type: Number, default: 0 },
  memo: { type: String, default: 'None' },
});

module.exports = mongoose.model('CallLog', callLogSchema);
