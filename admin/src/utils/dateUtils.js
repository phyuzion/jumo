// UTC <-> LOCAL 변환 함수 모음

// (A) 로컬 -> UTC 문자열
export function localTimeToUTCString(localDateOrString) {
  // localDateOrString이 문자열이면 Date로 파싱
  let dateObj = null;
  if (typeof localDateOrString === 'string') {
    dateObj = new Date(localDateOrString);
  } else {
    dateObj = localDateOrString; // Date 객체
  }

  // 파싱 실패 시 반환
  if (!dateObj || isNaN(dateObj.getTime())) return '';

  // toISOString()은 항상 UTC 기준의 ISO-8601 문자열(예: "2023-10-07T09:45:00.000Z")을 반환
  return dateObj.toISOString();
}

// (B) 서버(UTC/epoch) -> 로컬 표기
export function parseServerTimeToLocal(serverTime) {
  if (!serverTime) return '';

  // ISO 문자열인지 먼저 확인
  if (typeof serverTime === 'string' && serverTime.includes('T')) {
    const dtObj = new Date(serverTime);
    if (!isNaN(dtObj.getTime())) {
      return dtObj.toLocaleString('ko-KR', { timeZone: 'Asia/Seoul' });
    }
  }

  // epoch인지 판별
  let milli = parseInt(serverTime, 10);
  if (!isNaN(milli)) {
    // 10자리라면 초 단위이므로 밀리초로 환산
    if (serverTime.length === 10) {
      milli = milli * 1000;
    }
    const dateObj = new Date(milli);
    if (!isNaN(dateObj.getTime())) {
      return dateObj.toLocaleString('ko-KR', { timeZone: 'Asia/Seoul' });
    }
  }

  // 파싱 실패하면 원본 그대로
  return serverTime;
} 