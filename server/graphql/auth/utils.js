const jwt = require('jsonwebtoken');
const { ForbiddenError, AuthenticationError } = require('apollo-server-errors');
const User = require('../../models/User');

// JWT 설정
const SECRET_KEY = process.env.JWT_SECRET || 'someRandomSecretKey';
const ACCESS_TOKEN_EXPIRE = '1d';   // 1일
const REFRESH_TOKEN_EXPIRE = '7d'; // 7일

// JWT 관련 함수들
function generateAccessToken(payload) {
  return jwt.sign(payload, SECRET_KEY, { expiresIn: ACCESS_TOKEN_EXPIRE });
}

function generateRefreshToken(payload) {
  return jwt.sign(payload, SECRET_KEY, { expiresIn: REFRESH_TOKEN_EXPIRE });
}

function verifyRefreshToken(token) {
  try {
    return jwt.verify(token, SECRET_KEY);
  } catch (e) {
    return null;
  }
}

// 권한 체크 함수들
async function checkAdminValid(tokenData) {
  if (!tokenData?.adminId) {
    throw new ForbiddenError('관리자 권한이 필요합니다.');
  }
}

async function checkUserValid(tokenData) {
  if (!tokenData?.userId) {
    throw new AuthenticationError('로그인이 필요합니다.');
  }
  const user = await User.findById(tokenData.userId).select('validUntil password settings blockList');
  if (!user) {
    throw new ForbiddenError('유효하지 않은 유저입니다.');
  }
  if (user.validUntil && user.validUntil < new Date()) {
    throw new ForbiddenError('유효 기간이 만료된 계정입니다.');
  }
  return user;
}

async function checkUserOrAdmin(tokenData) {
  // 반환: { isAdmin: boolean, user: User doc or null }
  if (tokenData?.adminId) {
    return { isAdmin: true, user: null };
  } else if (tokenData?.userId) {
    const user = await User.findById(tokenData.userId).select('validUntil');
    if (!user) throw new ForbiddenError('유효하지 않은 유저입니다.');
    if (user.validUntil && user.validUntil < new Date()) {
      throw new ForbiddenError('유효 기간이 만료된 계정입니다.');
    }
    return { isAdmin: false, user };
  } else {
    throw new AuthenticationError('로그인이 필요합니다.');
  }
}

/*
  작성자 권한 or 관리자 권한 체크
  - 관리자면 바로 OK
  - 일반 유저라면 contentDoc.userId === tokenData.userId 이어야 함
*/
async function checkAuthorOrAdmin(tokenData, contentDoc) {
  if (tokenData?.adminId) {
    return; // 관리자
  }
  if (!tokenData?.userId) {
    throw new ForbiddenError('권한이 없습니다.(로그인 필요)');
  }
  const user = await User.findById(tokenData.userId);
  if (!user) {
    throw new ForbiddenError('유효하지 않은 유저입니다.(checkAuthorOrAdmin)');
  }
  // contentDoc.userId가 로그인 유저의 _id와 같아야 함
  if (contentDoc.userId !== user._id.toString()) {
    throw new ForbiddenError('수정/삭제 권한이 없습니다.');
  }
}

module.exports = {
  // JWT 관련
  generateAccessToken,
  generateRefreshToken,
  verifyRefreshToken,
  
  // 권한 체크
  checkAdminValid,
  checkUserValid,
  checkUserOrAdmin,
  checkAuthorOrAdmin,
  
  // 상수
  SECRET_KEY,
  ACCESS_TOKEN_EXPIRE,
  REFRESH_TOKEN_EXPIRE
}; 