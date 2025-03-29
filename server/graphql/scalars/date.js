const { GraphQLScalarType, Kind } = require('graphql');
const { utcToKst, toKstISOString } = require('../../utils/date');

/**
 * Date 객체를 ISO 문자열로 직렬화하는 스칼라 타입
 * UTC 시간을 KST로 변환하여 ISO 문자열로 반환
 */
const DateScalar = new GraphQLScalarType({
  name: 'Date',
  description: 'Date custom scalar type',
  
  // 값을 클라이언트에 보낼 때 (UTC Date -> ISO String)
  serialize(value) {
    if (value instanceof Date) {
      // Date 객체를 KST로 변환하여 ISO 문자열로 반환
      return toKstISOString(value);
    }
    return value;
  },
  
  // 클라이언트에서 받은 값을 파싱할 때 (ISO String -> Date)
  parseValue(value) {
    if (typeof value === 'string') {
      return new Date(value);
    }
    return null;
  },
  
  // 쿼리에서 리터럴 값을 파싱할 때
  parseLiteral(ast) {
    if (ast.kind === Kind.STRING) {
      return new Date(ast.value);
    }
    return null;
  }
});

module.exports = DateScalar; 