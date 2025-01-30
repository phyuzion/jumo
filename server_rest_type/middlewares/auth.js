// middlewares/auth.js
const jwt = require('jsonwebtoken');
const User = require('../models/User');

// 어드민용 JWT 인증
exports.adminAuth = (req, res, next) => {
  try {
    const token = req.headers.authorization?.split(' ')[1];
    if (!token) return res.status(401).json({ success: false, message: 'No token' });

    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    // decoded 안에 { adminId: "...", iat:..., exp:... } 가 있을 것
    req.adminId = decoded.adminId; 
    next();
  } catch (err) {
    return res.status(401).json({ success: false, message: 'Invalid token' });
  }
};

// 클라이언트(유저) 간단 인증
exports.userAuth = async (req, res, next) => {
  try {
    const { userId, phone } = req.body;
    if (!userId || !phone) {
      return res.status(401).json({ success: false, message: 'userId and phone required' });
    }

    const user = await User.findOne({ userId, phone });
    if (!user) {
      return res.status(401).json({ success: false, message: 'Invalid user credentials' });
    }

    // 유효기간 체크
    if (user.validUntil && user.validUntil < new Date()) {
      return res.status(403).json({ success: false, message: 'User expired' });
    }

    // 인증 통과 후 다음
    req.user = user;
    next();
  } catch (err) {
    return res.status(500).json({ success: false, error: err.message });
  }
};
