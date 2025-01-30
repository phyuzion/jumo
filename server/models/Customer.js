// models/Customer.js
const mongoose = require('mongoose');

const customerSchema = new mongoose.Schema({
  phone: { type: String, required: true, unique: true },
  totalCalls: { type: Number, default: 0 },
  averageScore: { type: Number, default: 0 },
});

module.exports = mongoose.model('Customer', customerSchema);
