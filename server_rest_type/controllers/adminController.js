// controllers/adminController.js
const jwt = require('jsonwebtoken');
const bcrypt = require('bcrypt');
const Admin = require('../models/Admin');
const User = require('../models/User');
const Customer = require('../models/Customer');
const CallLog = require('../models/CallLog');

// (예시) 어드민 로그인
exports.adminLogin = async (req, res) => {
  try {
    const { adminId, password } = req.body;
    const admin = await Admin.findOne({ adminId });
    if (!admin) {
      return res.status(401).json({ success: false, message: 'No admin found' });
    }

    // 비번 해싱/검증 로직 (bcrypt.compare)
    // 여기선 단순화
    const isMatch = (admin.password === password); 
    if (!isMatch) {
      return res.status(401).json({ success: false, message: 'Wrong password' });
    }

    // JWT 발급
    const token = jwt.sign({ adminId: admin.adminId }, process.env.JWT_SECRET, {
      expiresIn: '10m' // 10분
    });

    res.json({ success: true, token });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
};

// 유저 생성
exports.createUser = async (req, res) => {
  try {
    // 어드민 인증은 이미 routes 레벨에서 adminAuth 미들웨어가 처리
    const { phone, name, memo, validUntil } = req.body;
    
    // 6글자 userId 자동생성 (간단 예시)
    const randomId = Math.random().toString(36).substring(2, 8).toUpperCase();
    
    const newUser = await User.create({
      userId: randomId,
      phone,
      name,
      memo,
      validUntil,
    });

    res.json({ success: true, data: newUser });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
};

// 유저 수정
exports.updateUser = async (req, res) => {
  try {
    const { userId } = req.params; // /admin/users/:userId
    const { phone, name, memo, validUntil } = req.body;

    const updatedUser = await User.findOneAndUpdate(
      { userId },
      { phone, name, memo, validUntil },
      { new: true } // 수정된 문서 반환
    );

    if (!updatedUser) {
      return res.status(404).json({ success: false, message: 'User not found' });
    }

    res.json({ success: true, data: updatedUser });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
};

// 유저 조회
exports.getUsers = async (req, res) => {
  try {
    const { phone, name } = req.query;
    let filter = {};
    if (phone) filter.phone = phone;
    if (name) filter.name = name;

    const users = await User.find(filter);
    res.json({ success: true, data: users });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
};

// 고객 조회 (전화번호로)
exports.getCustomerByPhone = async (req, res) => {
  try {
    const { phone } = req.query;
    if (!phone) {
      return res.status(400).json({ success: false, message: 'phone is required' });
    }

    // 1) 고객 찾기
    const customer = await Customer.findOne({ phone });
    if (!customer) {
      return res.json({ success: true, data: null, callLogs: [] }); 
    }

    // 2) 콜로그 조회
    const logs = await CallLog.find({ customerId: customer._id })
                              .populate('userId', 'userId phone name'); 
    // userId, phone, name만 가져옴

    res.json({
      success: true,
      data: customer,
      callLogs: logs
    });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
};

// (선택) 고객 업데이트(고객명 변경) - 어드민이 가능하게
exports.updateCustomer = async (req, res) => {
  try {
    const { customerId } = req.params;
    const { name } = req.body;

    const updated = await Customer.findByIdAndUpdate(
      customerId,
      { name },
      { new: true }
    );

    res.json({ success: true, data: updated });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
};
