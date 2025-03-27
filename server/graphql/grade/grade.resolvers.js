const Grade = require('../../models/Grade');
const { checkAdminValid } = require('../auth/utils');

const resolvers = {
  Query: {
    getGrades: async () => {
      try {
        const grades = await Grade.find().sort({ name: 1 });
        return grades;
      } catch (error) {
        throw new Error('등급 목록을 가져오는데 실패했습니다.');
      }
    }
  },
  Mutation: {
    addGrade: async (_, { name, limit }, { tokenData }) => {
      await checkAdminValid(tokenData);

      const existingGrade = await Grade.findOne({ name });
      if (existingGrade) {
        throw new Error('이미 존재하는 등급입니다.');
      }

      const grade = new Grade({ name, limit });
      await grade.save();
      return grade;
    },
  }
};

module.exports = resolvers; 