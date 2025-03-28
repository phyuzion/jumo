const mongoose = require('mongoose');

const userTypeSchema = new mongoose.Schema({
  name: {
    type: String,
    required: true,
    unique: true,
    trim: true
  }
});

module.exports = mongoose.model('UserType', userTypeSchema);