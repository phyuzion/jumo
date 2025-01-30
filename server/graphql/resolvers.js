const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const Admin = require('../models/Admin');
const User = require('../models/User');
const Customer = require('../models/Customer');
const CallLog = require('../models/CallLog');

// [어드민 체크] - JWT Bearer
function checkAdmin(context) {
  if (!context.isAdmin) {
    throw new Error('Admin privileges required');
  }
}

// [유저 체크] - userId + phone
async function checkUserAuth(userId, phone) {
  const user = await User.findOne({ userId, phone });
  if (!user) {
    throw new Error('User auth failed (invalid userId/phone)');
  }
  if (user.validUntil && user.validUntil < new Date()) {
    throw new Error('User expired');
  }
  return user;
}

const resolvers = {
  // ==================================================
  //                    Query
  // ==================================================
  Query: {
    // -------------------------
    // [어드민 전용]
    // -------------------------
    getUserByPhone: async (_, { phone }, context) => {
      checkAdmin(context);
      return User.find({ phone: { $regex: phone, $options: 'i' } });
    },
    getUserByName: async (_, { name }, context) => {
      checkAdmin(context);
      return User.find({ name: { $regex: name, $options: 'i' } });
    },
    getUsers: async (_, { phone, name }, context) => {
      checkAdmin(context);
      const filter = {};
      if (phone) filter.phone = phone;
      if (name) filter.name = name;
      return User.find(filter);
    },


    // --- 새로 추가: getUserList / getCallLogs / getCustomers
    getUserList: async (_, { start, end }, context) => {
      checkAdmin(context);
      const skip = start - 1;
      const limit = end - start + 1;

      // 정렬 기준: _id 오름차순 (원하는 대로 바꿀 수 있음)
      const users = await User.find({})
        .sort({ _id: 1 })
        .skip(skip)
        .limit(limit);

      return users;
    },

    getCallLogs: async (_, { start, end }, context) => {
      checkAdmin(context);
      const skip = start - 1;
      const limit = end - start + 1;

      // 전체 콜로그, timestamp 역순
      const logs = await CallLog.find({})
        .populate('customerId')
        .populate('userId')
        .sort({ timestamp: -1 })
        .skip(skip)
        .limit(limit);

      return logs;
    },

    getCustomers: async (_, { start, end }, context) => {
      checkAdmin(context);
      const skip = start - 1;
      const limit = end - start + 1;

      // 정렬 기준: phone 오름차순 (필요에 따라 변경)
      const customers = await Customer.find({})
        .sort({ phone: 1 })
        .skip(skip)
        .limit(limit);

      return customers;
    },

    // -------------------------
    // [유저 전용] => (userId, phone) 인증
    // -------------------------
    getCustomerByPhone: async (_, { userId, phone, searchPhone }) => {
      // 유저 인증
      await checkUserAuth(userId, phone);

      // DB에서 고객들 검색 (부분검색 or 정확히 일치?)
      const customers = await Customer.find({
        phone: { $regex: searchPhone, $options: 'i' },
      });

      const results = [];
      for (const c of customers) {
        // 이 고객과 연관된 callLogs
        const logs = await CallLog.find({ customerId: c._id }).populate('userId');
        results.push({
          customer: c,
          callLogs: logs,
        });
      }
      return results;
    },

    getCallLogByID: async (_, { userId, phone, logId }) => {
      const user = await checkUserAuth(userId, phone);

      const log = await CallLog.findById(logId)
        .populate('userId')
        .populate('customerId');
      if (!log) throw new Error('CallLog not found');

      // 작성자가 내 user._id랑 같은지?
      if (log.userId && log.userId._id.toString() !== user._id.toString()) {
        throw new Error('Not your callLog');
      }
      return log;
    },

    // 통합 콜로그 목록 (start~end)
    getCallLogsForUser: async (_, { userId, phone, start, end }) => {
      const user = await checkUserAuth(userId, phone);

      const skip = start - 1;
      const limit = end - start + 1;

      const logs = await CallLog.find({ userId: user._id })
        .populate('customerId')
        .populate('userId')
        .sort({ timestamp: -1 })
        .skip(skip)
        .limit(limit);

      return logs;
    },

    getSummary: async (_, __, context) => {
      checkAdmin(context); // 어드민 권한 체크

      // 1) 각 모델의 countDocuments (또는 estimatedDocumentCount)
      const callLogsCount = await CallLog.countDocuments({});
      const usersCount = await User.countDocuments({});
      const customersCount = await Customer.countDocuments({});

      return {
        callLogsCount,
        usersCount,
        customersCount
      };
    },
  },

  // ==================================================
  //                  Mutation
  // ==================================================
  Mutation: {
    // -------------------------
    // [어드민 전용]
    // -------------------------
    createAdmin: async (_, { adminId, password }) => {
      const exist = await Admin.findOne({ adminId });
      if (exist) {
        throw new Error('Admin already exists');
      }
      const newAdmin = new Admin({ adminId, password });
      await newAdmin.save();
      return newAdmin;
    },

    adminLogin: async (_, { adminId, password }) => {
      const admin = await Admin.findOne({ adminId });
      if (!admin) {
        throw new Error('Admin not found');
      }
      const match = await bcrypt.compare(password, admin.password);
      if (!match) {
        throw new Error('Invalid password');
      }
      // JWT 발급
      const token = jwt.sign({ adminId: admin.adminId }, process.env.JWT_SECRET, {
        expiresIn: '1h',
      });
      return { token, adminId: admin.adminId };
    },

    createUser: async (_, { phone, name, memo, validUntil }, context) => {
      checkAdmin(context);

      // 6글자 userId 자동
      const userId = Math.random().toString(36).substring(2, 8).toUpperCase();
      const newUser = await User.create({
        userId,
        phone,
        name,
        memo,
        validUntil
      });
      return newUser;
    },

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

    // -------------------------
    // [유저 전용]
    // -------------------------
    clientLogin: async (_, { userId, phone }) => {
      const user = await User.findOne({ userId, phone });
      if (!user) return false;
      if (user.validUntil && user.validUntil < new Date()) return false;
      return true;
    },

    createCallLog: async (_, { userId, phone, customerPhone, score, memo }) => {
      // 유저 인증
      const user = await User.findOne({ userId, phone });
      if (!user) {
        throw new Error('Invalid user or expired');
      }

      // 고객 찾거나 생성
      let customer = await Customer.findOne({ phone: customerPhone });
      if (!customer) {
        customer = await Customer.create({
          phone: customerPhone,
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

    updateCallLog: async (_, { logId, userId, phone, score, memo }) => {
      // 유저 인증
      const user = await User.findOne({ userId, phone });
      if (!user) {
        throw new Error('Invalid user or expired');
      }
      const callLog = await CallLog.findById(logId);
      if (!callLog) {
        throw new Error('CallLog not found');
      }

      // 작성자가 내 user._id인지 확인
      if (callLog.userId.toString() !== user._id.toString()) {
        throw new Error('Not your callLog');
      }

      // 업데이트
      const oldScore = callLog.score;
      if (score !== undefined) callLog.score = score;
      if (memo !== undefined) callLog.memo = memo;
      await callLog.save();

      // 점수 변경 시 평균 재계산
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

  // CallLog 필드 리졸버
  CallLog: {
    customerId: async (parent) => Customer.findById(parent.customerId),
    userId: async (parent) => User.findById(parent.userId),
  },
};

module.exports = resolvers;
