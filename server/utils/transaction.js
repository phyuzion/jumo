const mongoose = require('mongoose');

const withTransaction = async (operation) => {
  const session = await mongoose.startSession();
  session.startTransaction();
  try {
    const result = await operation(session);
    await session.commitTransaction();
    return result;
  } catch (error) {
    await session.abortTransaction();
    throw error;
  } finally {
    session.endSession();
  }
};

module.exports = { withTransaction }; 