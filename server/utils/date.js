/**
 * KST 시간을 UTC로 변환
 * @param {Date|string} kstDate KST 시간 (Date 객체 또는 ISO 문자열)
 * @returns {Date} UTC Date 객체
 */
function kstToUtc(kstDate) {
  const date = kstDate instanceof Date ? kstDate : new Date(kstDate);
  return new Date(date.getTime() - (9 * 60 * 60 * 1000)); // KST -> UTC
}

/**
 * UTC 시간을 KST로 변환
 * @param {Date|string} utcDate UTC 시간 (Date 객체 또는 ISO 문자열)
 * @returns {Date} KST Date 객체
 */
function utcToKst(utcDate) {
  const date = utcDate instanceof Date ? utcDate : new Date(utcDate);
  return new Date(date.getTime() + (9 * 60 * 60 * 1000)); // UTC -> KST
}

/**
 * Date 객체를 ISO 문자열로 변환 (KST)
 * @param {Date} date Date 객체
 * @returns {string} ISO 문자열 (KST)
 */
function toKstISOString(date) {
  return utcToKst(date).toISOString();
}

module.exports = {
  kstToUtc,
  utcToKst,
  toKstISOString
}; 