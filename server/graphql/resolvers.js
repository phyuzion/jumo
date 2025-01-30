const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const Admin = require('../models/Admin');
const User = require('../models/User');
const Customer = require('../models/Customer');
const CallLog = require('../models/CallLog');

// 어드민 권한 체크 함수
function checkAdmin(context) {
  if (!context.isAdmin) {
    throw new Error('Admin privileges required');
  }
}

const resolvers = {
  // ===================
  //       Query
  // ===================
  Query: {
    // [어드민 전용] 단일 유저 조회 (phone)
    getUserByPhone: async (_, { phone }, context) => {
      checkAdmin(context);
      
      // 부분 검색(Regex): phone이 포함된 모든 유저
      return User.find({
        phone: { $regex: phone, $options: 'i' },
      });
    },

    // [어드민 전용] 유저 조회 (이름)
    getUserByName: async (_, { name }, context) => {
      checkAdmin(context);
      
      return User.find({
        name: { $regex: name, $options: 'i' },
      });
    },

    // [어드민 전용] 유저 목록
    getUsers: async (_, { phone, name }, context) => {
      checkAdmin(context);
      const filter = {};
      if (phone) filter.phone = phone;
      if (name) filter.name = name;
      return User.find(filter);
    },

    // [유저/공개] 고객 조회 (전화번호)
    getCustomerByPhone: async (_, { phone }) => {
      // 필요하면 user 인증 검증

      // phone에 부분일치
      const customers = await Customer.find({
        phone: { $regex: phone, $options: 'i' },
      });
      
      // 각 고객마다 callLogs를 조회해 CustomerResult로 묶어서 반환
      const results = [];
      for (const c of customers) {
        const logs = await CallLog.find({ customerId: c._id }).populate('userId');
        results.push({
          customer: c,
          callLogs: logs,
        });
      }

      return results;
    },

    // [유저/공개] 고객 조회 (이름)
    getCustomerByName: async (_, { name }) => {
      // 부분 검색
      const customers = await Customer.find({
        name: { $regex: name, $options: 'i' },
      });

      const results = [];
      for (const c of customers) {
        const logs = await CallLog.find({ customerId: c._id }).populate('userId');
        results.push({
          customer: c,
          callLogs: logs,
        });
      }
      return results;
    },

    // 전체 콜로그 개수
    getTotalCallLogs: async (_, { customerId }) => {
      // ex) countDocuments
      const count = await CallLog.countDocuments({ customerId });
      return count;
    },

    // 최신 limit개의 콜로그
    getCallLogs: async (_, { customerId, limit }) => {
      const queryLimit = limit || 10; // 디폴트 10
      const logs = await CallLog.find({ customerId })
        .populate('userId')
        .populate('customerId')
        .sort({ timestamp: -1 }) // 최신순
        .limit(queryLimit);
      return logs;
    },

    getCallLogByID: async (_, { logId }) => {
      const log = await CallLog.findById(logId)
        .populate('userId')      // 유저 정보도 같이
        .populate('customerId'); // 고객 정보도 같이
    
      if (!log) {
        throw new Error('CallLog not found');
      }
      return log;
    },
    
  },

  // ===================
  //     Mutation
  // ===================
  Mutation: {
    // (A) 어드민 생성
    createAdmin: async (_, { adminId, password }) => {
      // 여기서는 슈퍼 어드민 체크 생략
      const exist = await Admin.findOne({ adminId });
      if (exist) {
        throw new Error('Admin already exists');
      }
      const newAdmin = new Admin({ adminId, password });
      await newAdmin.save();
      return newAdmin;
    },

    // (B) 어드민 로그인
    adminLogin: async (_, { adminId, password }) => {
      const admin = await Admin.findOne({ adminId });
      if (!admin) {
        throw new Error('Admin not found');
      }
      const match = await bcrypt.compare(password, admin.password);
      if (!match) {
        throw new Error('Invalid password');
      }
      const token = jwt.sign({ adminId: admin.adminId }, process.env.JWT_SECRET, {
        expiresIn: '1h'
      });
      return {
        token,
        adminId: admin.adminId,
      };
    },

    // (C) 유저 생성 [어드민]
    createUser: async (_, { phone, name, memo, validUntil }, context) => {
      checkAdmin(context);

      // 6글자 ID 자동
      const userId = Math.random().toString(36).substring(2, 8).toUpperCase();
      const newUser = await User.create({ userId, phone, name, memo, validUntil });
      return newUser;
    },

    // (D) 유저 수정 [어드민]
    updateUser: async (_, { userId, phone, name, memo, validUntil }, context) => {
      checkAdmin(context);

      const updated = await User.findOneAndUpdate(
        { userId },
        { phone, name, memo, validUntil },
        { new: true }
      );
      if (!updated) {
        throw new Error('User not found');
      }
      return updated;
    },

    // (E) 클라이언트 로그인
    clientLogin: async (_, { userId, phone }) => {
      const user = await User.findOne({ userId, phone });
      if (!user) return false;
      if (user.validUntil && user.validUntil < new Date()) return false;
      return true;
    },

    // (F) 콜로그 생성
    createCallLog: async (_, { userId, phone, customerPhone, score, memo }) => {
      // 유저 검증
      const user = await User.findOne({ userId, phone });
      if (!user) {
        throw new Error('Invalid user or expired');
      }
      // 고객 찾기 or 생성
      let customer = await Customer.findOne({ phone: customerPhone });
      if (!customer) {
        customer = await Customer.create({
          phone: customerPhone,
          name: 'None',
          totalCalls: 0,
          averageScore: 0
        });
      }
      // 콜로그 생성
      const newLog = await CallLog.create({
        customerId: customer._id,
        userId: user._id,
        timestamp: new Date(),
        score: score || 0,
        memo: memo || 'None',
      });
      // 고객 평균점수 갱신
      const newTotal = customer.totalCalls + 1;
      const newAvg = ((customer.averageScore * customer.totalCalls) + (score || 0)) / newTotal;
      customer.totalCalls = newTotal;
      customer.averageScore = newAvg;
      await customer.save();

      return {
        callLog: newLog,
        customer
      };
    },

    // (G) 콜로그 수정
    updateCallLog: async (_, { logId, userId, phone, score, memo }) => {
      // 유저 검증
      const user = await User.findOne({ userId, phone });
      if (!user) {
        throw new Error('Invalid user or expired');
      }
      const callLog = await CallLog.findById(logId);
      if (!callLog) {
        throw new Error('CallLog not found');
      }
      // (작성자만 수정 가능하게 하려면 검증 로직 추가)
      const oldScore = callLog.score;
      if (score !== undefined) callLog.score = score;
      if (memo !== undefined) callLog.memo = memo;
      await callLog.save();

      // score 변경 → 평균점수 재계산
      if (score !== undefined && score !== oldScore) {
        const customer = await Customer.findById(callLog.customerId);
        if (customer) {
          const logs = await CallLog.find({ customerId: customer._id });
          const totalCalls = logs.length;
          const sumScores = logs.reduce((acc, l) => acc + (l.score || 0), 0);
          customer.totalCalls = totalCalls;
          customer.averageScore = sumScores / totalCalls;
          await customer.save();
        }
      }
      return callLog;
    },
  },

  // (선택) CallLog 필드 자동 Resolvers
  CallLog: {
    customerId: async (parent) => {
      return Customer.findById(parent.customerId);
    },
    userId: async (parent) => {
      return User.findById(parent.userId);
    },
  },
};

module.exports = resolvers;
