const Region = require('../../models/Region');
const { checkAdminValid } = require('../auth/utils');

const resolvers = {
  Query: {
    getRegions: async () => {
      try {
        const regions = await Region.find().sort({ name: 1 });
        return regions;
      } catch (error) {
        throw new Error('지역 목록을 가져오는데 실패했습니다.');
      }
    }
  },
  Mutation: {
    addRegion: async (_, { name }, { tokenData }) => {
      await checkAdminValid(tokenData);

      const existingRegion = await Region.findOne({ name });
      if (existingRegion) {
        throw new Error('이미 존재하는 지역입니다.');
      }

      const region = new Region({ name });
      await region.save();
      return region;
    },
  }
};

module.exports = resolvers; 