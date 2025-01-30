// routes/adminRoutes.js
const express = require('express');
const router = express.Router();
const { adminAuth } = require('../middlewares/auth');
const {
  adminLogin,
  createUser,
  updateUser,
  getUsers,
  getCustomerByPhone,
  updateCustomer
} = require('../controllers/adminController');

// POST /admin/login
router.post('/login', adminLogin);

// 아래는 모두 adminAuth 토큰 검증이 필요
router.post('/users', adminAuth, createUser);
router.put('/users/:userId', adminAuth, updateUser);
router.get('/users', adminAuth, getUsers);

router.get('/customers', adminAuth, getCustomerByPhone);
router.put('/customers/:customerId', adminAuth, updateCustomer);

module.exports = router;
