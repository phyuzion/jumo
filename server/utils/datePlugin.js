/**
 * Mongoose 플러그인: Date 필드를 특별 처리하여 이중 변환 문제 해결
 * 모든 Date 타입 필드에 메타데이터를 추가하여 GraphQL 레이어에서
 * 이미 처리된 필드와 그렇지 않은 필드를 구분할 수 있게 함
 */
const datePlugin = schema => {
  // toJSON/toObject 옵션 설정
  const origToJSON = schema.options.toJSON || {};
  const origTransform = origToJSON.transform;

  schema.set('toJSON', {
    ...origToJSON,
    transform: function(doc, ret, options) {
      // 원래 있던 transform 함수 호출
      if (origTransform) {
        ret = origTransform(doc, ret, options);
      }

      // Date 필드 처리
      processObject(ret);
      
      return ret;
    }
  });

  // toObject 옵션도 동일하게 설정
  const origToObject = schema.options.toObject || {};
  const origToObjectTransform = origToObject.transform;

  schema.set('toObject', {
    ...origToObject,
    transform: function(doc, ret, options) {
      // 원래 있던 transform 함수 호출
      if (origToObjectTransform) {
        ret = origToObjectTransform(doc, ret, options);
      }

      // Date 필드 처리
      processObject(ret);
      
      return ret;
    }
  });

  // 재귀적으로 객체의 모든 Date 필드 처리
  function processObject(obj) {
    if (!obj || typeof obj !== 'object') return;

    Object.keys(obj).forEach(key => {
      const value = obj[key];
      
      // 이미 처리된 객체는 건너뜀 (무한 루프 방지)
      if (value && typeof value === 'object' && value.__dateType === 'utc') {
        return;
      }
      
      if (value instanceof Date) {
        // Date 객체에 메타데이터 추가
        obj[key] = {
          value: value.toISOString(),
          __dateType: 'utc'
        };
      } else if (Array.isArray(value)) {
        // 배열의 각 요소 처리
        value.forEach(item => {
          if (item && typeof item === 'object') {
            processObject(item);
          }
        });
      } else if (value && typeof value === 'object' && !(value instanceof Date)) {
        // 중첩 객체 처리
        processObject(value);
      }
    });
  }
};

module.exports = datePlugin; 