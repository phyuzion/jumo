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

// MongoDB에서 가져온 ISO 문자열인지 확인 (타임존 표시가 있는지)
function isMongoDBIsoString(str) {
  return typeof str === 'string' && 
         str.includes('T') && 
         (str.endsWith('Z') || str.includes('+00:00') || str.includes('+0000'));
}

// ISO 문자열에서 타임존 제거하고 +09:00 추가
function convertToKstIsoString(isoStr) {
  // UTC ISO 문자열에서 타임존 부분 제거
  let baseStr = isoStr;
  if (baseStr.endsWith('Z')) {
    baseStr = baseStr.slice(0, -1);
  } else if (baseStr.includes('+')) {
    baseStr = baseStr.split('+')[0];
  }
  
  // KST 타임존 추가
  return `${baseStr}+09:00`;
}

/**
 * Date 객체 및 날짜 문자열을 직렬화하는 스칼라 타입
 * - 서버에서 클라이언트로: UTC -> KST
 * - 클라이언트에서 서버로: KST -> UTC
 */
const DateScalar = new GraphQLScalarType({
  name: 'Date',
  description: 'Date custom scalar type with timezone handling',
  
  // 값을 클라이언트에 보낼 때
  serialize(value) {
    // null/undefined 처리
    if (value == null) {
      return value;
    }
    
    // 이미 문자열로 변환된 KST 시간이면 그대로 반환 (무한 루프 방지)
    if (typeof value === 'string' && value.includes('+09:00')) {
      return value;
    }
    
    // 1. datePlugin에서 처리된 특별 구조 확인
    if (value && typeof value === 'object' && value.__dateType === 'utc') {
      // ISO 문자열이 이미 있으면 그것을 사용
      if (value.value) {
        const date = new Date(value.value);
        return toKstISOString(date);
      }
    }
    
    // 2. MongoDB에서 이미 ISO 문자열로 변환된 경우 (타임존 +00:00 포함)
    if (isMongoDBIsoString(value)) {
      // UTC 시간 -> KST 타임존으로 변환
      return convertToKstIsoString(value);
    }
    
    // 3. Date 객체인 경우
    if (value instanceof Date) {
      return toKstISOString(value);
    }
    
    // 4. 다른 형태의 문자열은 Date로 파싱 시도
    if (typeof value === 'string' && value.includes('T')) {
      try {
        const date = new Date(value);
        if (!isNaN(date.getTime())) {
          return toKstISOString(date);
        }
      } catch (e) {
        console.error('Date parsing error:', e);
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