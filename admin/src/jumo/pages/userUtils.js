/**
 * 사용자 설정 문자열을 파싱하여 디바이스 정보를 추출합니다.
 * @param {string} settingsString - JSON 형식의 설정 문자열
 * @returns {Object|null} 파싱된 디바이스 정보 또는 null
 */
export function parseUserSettings(settingsString) {
  if (!settingsString) return null;
  
  try {
    const settings = JSON.parse(settingsString);
    return {
      model: settings.deviceInfo?.model || 'Unknown',
      osVersion: settings.deviceInfo?.androidVersion || settings.deviceInfo?.systemVersion || 'Unknown',
      appVersion: settings.appVersion || 'Unknown',
      platform: settings.platform || 'Unknown',
      lastUpdateTime: settings.lastUpdateTime ? new Date(settings.lastUpdateTime).toLocaleString() : 'Unknown'
    };
  } catch (e) {
    console.error("Error parsing settings:", e);
    return null;
  }
}

/**
 * 디바이스 정보를 표시용 문자열로 포맷팅합니다.
 * @param {Object} deviceInfo - 파싱된 디바이스 정보
 * @returns {string} 포맷팅된 디바이스 정보 문자열
 */
export function formatDeviceInfo(deviceInfo) {
  if (!deviceInfo) return "정보 없음";
  
  return `${deviceInfo.model || 'Unknown'}\n${deviceInfo.platform || ''} ${deviceInfo.osVersion || ''}\nApp ${deviceInfo.appVersion || ''}`;
} 