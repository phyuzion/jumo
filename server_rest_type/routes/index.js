// routes/index.js
const express = require('express');
const router = express.Router();

// 서브 라우트 임포트
const adminRoutes = require('./adminRoutes');
const clientRoutes = require('./clientRoutes');

router.use('/admin', adminRoutes);
router.use('/client', clientRoutes);

module.exports = router;
