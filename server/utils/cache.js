const NodeCache = require('node-cache');

// 캐시 설정
// - stdTTL: 캐시 유효 시간 (초)
// - checkperiod: 만료된 캐시 정리 주기 (초)
// - useClones: 객체 복사 여부 (false로 설정하여 메모리 사용량 최적화)
const cache = new NodeCache({
  stdTTL: 300,  // 5분
  checkperiod: 60,  // 1분마다 만료된 캐시 정리
  useClones: false,
  maxKeys: 10000  // 최대 캐시 키 수 제한
});

// 캐시 키 상수
const CACHE_KEYS = {
  PHONE_NUMBER: (phoneNumber) => `phone:${phoneNumber}`,
  USER_RECORDS: (userId) => `user_records:${userId}`,
  USER_SETTINGS: (userId) => `user_settings:${userId}`,
  BLOCK_NUMBERS: (count) => `block_numbers:${count}`,
  TODAY_RECORDS: (phoneNumber) => `today_records:${phoneNumber}`,
  USER_CALL_LOGS: (userId) => `user_call_logs:${userId}`,
  USER_SMS_LOGS: (userId) => `user_sms_logs:${userId}`,
  ALL_USERS: 'all_users'
};

// 캐시 매니저 클래스
class CacheManager {
  // 전화번호 정보 캐싱
  static async getPhoneNumber(phoneNumber) {
    const key = CACHE_KEYS.PHONE_NUMBER(phoneNumber);
    return cache.get(key);
  }

  static setPhoneNumber(phoneNumber, data) {
    const key = CACHE_KEYS.PHONE_NUMBER(phoneNumber);
    cache.set(key, data);
  }

  // 유저 레코드 캐싱
  static async getUserRecords(userId) {
    const key = CACHE_KEYS.USER_RECORDS(userId);
    return cache.get(key);
  }

  static setUserRecords(userId, data) {
    const key = CACHE_KEYS.USER_RECORDS(userId);
    cache.set(key, data);
  }

  // 유저 설정 캐싱
  static async getUserSettings(userId) {
    const key = CACHE_KEYS.USER_SETTINGS(userId);
    return cache.get(key);
  }

  static setUserSettings(userId, data) {
    const key = CACHE_KEYS.USER_SETTINGS(userId);
    cache.set(key, data);
  }

  // 차단된 번호 목록 캐싱
  static async getBlockNumbers(count) {
    const key = CACHE_KEYS.BLOCK_NUMBERS(count);
    return cache.get(key);
  }

  static setBlockNumbers(count, data) {
    const key = CACHE_KEYS.BLOCK_NUMBERS(count);
    cache.set(key, data);
  }

  static invalidateBlockNumbers(count) {
    const key = CACHE_KEYS.BLOCK_NUMBERS(count);
    cache.del(key);
  }

  // 오늘의 레코드 캐싱
  static async getTodayRecords(phoneNumber) {
    const key = CACHE_KEYS.TODAY_RECORDS(phoneNumber);
    return cache.get(key);
  }

  static setTodayRecords(phoneNumber, data) {
    const key = CACHE_KEYS.TODAY_RECORDS(phoneNumber);
    cache.set(key, data);
  }

  // 유저 통화 기록 캐싱
  static async getUserCallLogs(userId) {
    const key = CACHE_KEYS.USER_CALL_LOGS(userId);
    return cache.get(key);
  }

  static setUserCallLogs(userId, data) {
    const key = CACHE_KEYS.USER_CALL_LOGS(userId);
    cache.set(key, data);
  }

  // 유저 SMS 기록 캐싱
  static async getUserSMSLogs(userId) {
    const key = CACHE_KEYS.USER_SMS_LOGS(userId);
    return cache.get(key);
  }

  static setUserSMSLogs(userId, data) {
    const key = CACHE_KEYS.USER_SMS_LOGS(userId);
    cache.set(key, data);
  }

  // 전체 유저 목록 캐싱
  static async getAllUsers() {
    return cache.get(CACHE_KEYS.ALL_USERS);
  }

  static setAllUsers(data) {
    cache.set(CACHE_KEYS.ALL_USERS, data);
  }

  // 캐시 무효화
  static invalidatePhoneNumber(phoneNumber) {
    const key = CACHE_KEYS.PHONE_NUMBER(phoneNumber);
    cache.del(key);
  }

  static invalidateUserRecords(userId) {
    const key = CACHE_KEYS.USER_RECORDS(userId);
    cache.del(key);
  }

  static invalidateUserSettings(userId) {
    const key = CACHE_KEYS.USER_SETTINGS(userId);
    cache.del(key);
  }

  static invalidateTodayRecords(phoneNumber) {
    const key = CACHE_KEYS.TODAY_RECORDS(phoneNumber);
    cache.del(key);
  }

  static invalidateUserCallLogs(userId) {
    const key = CACHE_KEYS.USER_CALL_LOGS(userId);
    cache.del(key);
  }

  static invalidateUserSMSLogs(userId) {
    const key = CACHE_KEYS.USER_SMS_LOGS(userId);
    cache.del(key);
  }

  static invalidateAllUsers() {
    cache.del(CACHE_KEYS.ALL_USERS);
  }

  // 캐시 통계
  static getStats() {
    return cache.getStats();
  }
}

module.exports = CacheManager; 