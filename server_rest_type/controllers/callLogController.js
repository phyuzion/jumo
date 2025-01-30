// controllers/callLogController.js
const CallLog = require('../models/CallLog');
const Customer = require('../models/Customer');

exports.createCallLog = async (req, res) => {
  try {
    // userAuth 미들웨어에서 req.user를 넣어줬다고 가정
    const user = req.user; 
    const { customerPhone, score, memo } = req.body;

    // 1) 고객 찾거나 생성
    let customer = await Customer.findOne({ phone: customerPhone });
    if (!customer) {
      customer = await Customer.create({
        phone: customerPhone,
        name: 'None',
        totalCalls: 0,
        averageScore: 0
      });
    }

    // 2) 콜로그 생성
    const newLog = await CallLog.create({
      customerId: customer._id,
      userId: user._id,
      timestamp: new Date(),
      score,
      memo,
    });

    // 3) 통계 업데이트 (avg score, totalCalls)
    const newTotal = customer.totalCalls + 1;
    const newAvg = (customer.averageScore * customer.totalCalls + score) / newTotal;

    customer.totalCalls = newTotal;
    customer.averageScore = newAvg;
    await customer.save();

    res.status(201).json({
      success: true,
      data: {
        callLog: newLog,
        customer
      }
    });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
};

exports.updateCallLog = async (req, res) => {
  try {
    // userAuth 미들웨어 통해 req.user 확인
    const { logId } = req.params;
    const { score, memo } = req.body;

    const callLog = await CallLog.findById(logId);
    if (!callLog) {
      return res.status(404).json({ success: false, message: 'CallLog not found' });
    }

    // 기존 score
    const oldScore = callLog.score;

    // 업데이트
    if (score !== undefined) callLog.score = score;
    if (memo !== undefined) callLog.memo = memo;
    await callLog.save();

    // score가 변경되었다면 customer 평균도 다시 계산
    if (score !== undefined && score !== oldScore) {
      const customer = await Customer.findById(callLog.customerId);
      if (customer) {
        // 전체 콜로그를 다시 조회하여 평균을 구하는 방법(간단하지만 쿼리 多)
        // or 기존 평균에서 차이만큼 보정 (조금 더 복잡)
        
        const logs = await CallLog.find({ customerId: customer._id });
        const totalCalls = logs.length;
        const sumScores = logs.reduce((acc, log) => acc + log.score, 0);
        const newAvg = sumScores / totalCalls;
        
        customer.totalCalls = totalCalls;
        customer.averageScore = newAvg;
        await customer.save();
      }
    }

    res.json({ success: true, data: callLog });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
};

exports.getCustomerByPhoneClient = async (req, res) => {
  try {
    const { customerPhone } = req.query;
    if (!customerPhone) {
      return res.status(400).json({ success: false, message: 'customerPhone required' });
    }

    const customer = await Customer.findOne({ phone: customerPhone });
    if (!customer) {
      return res.json({ success: true, data: null, callLogs: [] });
    }

    const callLogs = await CallLog.find({ customerId: customer._id }).sort({ timestamp: -1 });
    res.json({ success: true, data: customer, callLogs });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
};
