const mongoose = require('mongoose');
const CacheManager = require('./cache');

const withTransaction = async (operation, options = {}) => {
  const { invalidateCache = [] } = options;
  const session = await mongoose.startSession();
  session.startTransaction();
  
  try {
    const result = await operation(session);
    await session.commitTransaction();
    
    // 트랜잭션 성공 시 캐시 무효화
    if (invalidateCache.length > 0) {
      invalidateCache.forEach(key => {
        if (typeof key === 'function') {
          key(result);
        } else {
          CacheManager.invalidate(key);
        }
      });
    }
    
    return result;
  } catch (error) {
    await session.abortTransaction();
    throw error;
  } finally {
    session.endSession();
  }
};

module.exports = { withTransaction }; 