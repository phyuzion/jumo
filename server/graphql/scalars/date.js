const { GraphQLScalarType, Kind } = require('graphql');

/**
 * 시간 변환 유틸리티 함수
 */
// KST 시간을 UTC로 변환
function kstToUtc(kstDate) {
  const date = kstDate instanceof Date ? kstDate : new Date(kstDate);
  return new Date(date.getTime() - (9 * 60 * 60 * 1000)); // KST -> UTC
}

// UTC 시간을 KST로 변환
function utcToKst(utcDate) {
  const date = utcDate instanceof Date ? utcDate : new Date(utcDate);
  return new Date(date.getTime() + (9 * 60 * 60 * 1000)); // UTC -> KST
}

// Date 객체를 KST ISO 문자열로 변환
function toKstISOString(date) {
  const kst = utcToKst(date);
  const year = kst.getFullYear();
  const month = String(kst.getMonth() + 1).padStart(2, '0');
  const day = String(kst.getDate()).padStart(2, '0');
  const hours = String(kst.getHours()).padStart(2, '0');
  const minutes = String(kst.getMinutes()).padStart(2, '0');
  const seconds = String(kst.getSeconds()).padStart(2, '0');
  const milliseconds = String(kst.getMilliseconds()).padStart(3, '0');
  return `${year}-${month}-${day}T${hours}:${minutes}:${seconds}.${milliseconds}`;
}

/**
 * Date 객체를 ISO 문자열로 직렬화하는 스칼라 타입
 * 일관된 시간 변환 처리
 */
const DateScalar = new GraphQLScalarType({
  name: 'Date',
  description: 'Date custom scalar type with timezone conversion',
  
  // 값을 클라이언트에 보낼 때 (UTC Date -> KST ISO String)
  serialize(value) {
    // null/undefined 처리
    if (value == null) {
      return value;
    }
    
    // Date 객체 처리
    if (value instanceof Date) {
      // UTC Date 객체를 KST로 변환하여 ISO 문자열로 반환
      return toKstISOString(value);
    }
    
    // 문자열이면 ISO 형식인지 확인하고 UTC로 가정하여 KST로 변환
    if (typeof value === 'string' && value.includes('T')) {
      try {
        const date = new Date(value);
        if (!isNaN(date.getTime())) {
          return toKstISOString(date);
        }
      } catch (e) {
        // 파싱 오류 시 원본 그대로 반환
      }
    }
    
    // 그 외 값은 그대로 반환
    return value;
  },
  
  // 클라이언트에서 받은 값을 파싱할 때 (ISO String -> UTC Date)
  parseValue(value) {
    if (typeof value === 'string') {
      // KST 시간으로 입력된 문자열을 UTC Date로 변환
      return kstToUtc(new Date(value));
    }
    return null;
  },
  
  // 쿼리에서 리터럴 값을 파싱할 때
  parseLiteral(ast) {
    if (ast.kind === Kind.STRING) {
      // KST 시간으로 입력된 문자열을 UTC Date로 변환
      return kstToUtc(new Date(ast.value));
    }
    return null;
  }
});

// DateScalar와 함께 유틸리티 함수도 내보냄
module.exports = {
  DateScalar,
  kstToUtc,
  utcToKst,
  toKstISOString
}; 