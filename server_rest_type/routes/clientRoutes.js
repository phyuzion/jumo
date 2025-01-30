// routes/clientRoutes.js
const express = require('express');
const router = express.Router();
const { userAuth } = require('../middlewares/auth');
const { clientLogin } = require('../controllers/userController');
const {
  createCallLog,
  updateCallLog,
  getCustomerByPhoneClient
} = require('../controllers/callLogController');

// 로그인 (간단 인증)
router.post('/login', clientLogin);

// 콜로그 관련 -> userAuth 미들웨어 적용
router.post('/callLogs', userAuth, createCallLog);
router.put('/callLogs/:logId', userAuth, updateCallLog);

// 고객 조회
router.get('/customers', userAuth, getCustomerByPhoneClient);

module.exports = router;
