// controllers/userController.js
const User = require('../models/User');

exports.clientLogin = async (req, res) => {
  try {
    const { userId, phone } = req.body;
    // 별도의 userAuth 미들웨어를 쓰기 전, 여기서 직접 검증 가능
    const user = await User.findOne({ userId, phone });
    if (!user) {
      return res.status(401).json({ success: false, message: 'Invalid user' });
    }
    if (user.validUntil && user.validUntil < new Date()) {
      return res.status(403).json({ success: false, message: 'User expired' });
    }
    // 로그인 성공
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
};
