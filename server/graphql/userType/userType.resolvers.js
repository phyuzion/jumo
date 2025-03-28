const UserType = require('../../models/userType');
const { checkAdminValid } = require('../auth/utils');

const resolvers = {
  Query: {
    getUserTypes: async () => {
      try {
        const userTypes = await UserType.find().sort({ name: 1 });
        return userTypes;
      } catch (error) {
        throw new Error('유저 타입 목록을 가져오는데 실패했습니다.');
      }
    }
  },
  Mutation: {
    addUserType: async (_, { name }, { tokenData }) => {
      await checkAdminValid(tokenData);

      const existingUserType = await UserType.findOne({ name });
      if (existingUserType) {
        throw new Error('이미 존재하는 유저 타입입니다.');
      }

      const userType = new UserType({ name });
      await userType.save();
      return userType;
    },
  }
};

module.exports = resolvers; 