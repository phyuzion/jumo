import 'package:hive_ce/hive.dart';

// Hive 'settings' box 키 정의 (자주 사용될 것 같은 항목들)
const String _screenWidthKey = 'screenWidth';
const String _screenHeightKey = 'screenHeight';
const String _isTodayBlockedKey = 'isTodayBlocked';
const String _isUnknownBlockedKey = 'isUnknownBlocked';
const String _isAutoBlockDangerKey = 'isAutoBlockDanger';
const String _isBombCallsBlockedKey = 'isBombCallsBlocked';
const String _bombCallsCountKey = 'bombCallsCount';
const String _lastSmsSyncTimestampKey = 'lastSmsUploadTimestamp';
// ... 다른 설정 키들 필요 시 추가 ...

/// 앱 설정 데이터 접근을 위한 추상 클래스 (인터페이스)
abstract class SettingsRepository {
  // --- 화면 크기 ---
  Future<double?> getScreenWidth();
  Future<void> setScreenWidth(double width);
  Future<double?> getScreenHeight();
  Future<void> setScreenHeight(double height);

  // --- 차단 설정 --- (기본값 처리 포함)
  Future<bool> isTodayBlocked();
  Future<void> setTodayBlocked(bool value);
  Future<bool> isUnknownBlocked();
  Future<void> setUnknownBlocked(bool value);
  Future<bool> isAutoBlockDanger();
  Future<void> setAutoBlockDanger(bool value);
  Future<bool> isBombCallsBlocked();
  Future<void> setBombCallsBlocked(bool value);
  Future<int> getBombCallsCount();
  Future<void> setBombCallsCount(int count);

  // --- SMS 동기화 타임스탬프 --- (추가)
  Future<int> getLastSmsSyncTimestamp();
  Future<void> setLastSmsSyncTimestamp(int timestamp);

  // --- 일반 설정 값 접근 (Key 직접 사용) --- (선택적)
  // Future<T?> getSetting<T>(String key, {T? defaultValue});
  // Future<void> setSetting<T>(String key, T value);
}

/// Hive를 사용하여 SettingsRepository 인터페이스를 구현하는 클래스
class HiveSettingsRepository implements SettingsRepository {
  final Box _settingsBox;

  HiveSettingsRepository(this._settingsBox);

  // --- 화면 크기 구현 ---
  @override
  Future<double?> getScreenWidth() async {
    return Future.value(_settingsBox.get(_screenWidthKey) as double?);
  }

  @override
  Future<void> setScreenWidth(double width) async {
    await _settingsBox.put(_screenWidthKey, width);
  }

  @override
  Future<double?> getScreenHeight() async {
    return Future.value(_settingsBox.get(_screenHeightKey) as double?);
  }

  @override
  Future<void> setScreenHeight(double height) async {
    await _settingsBox.put(_screenHeightKey, height);
  }

  // --- 차단 설정 구현 (기본값 false 또는 0 처리) ---
  @override
  Future<bool> isTodayBlocked() async {
    return Future.value(
      _settingsBox.get(_isTodayBlockedKey, defaultValue: false) as bool,
    );
  }

  @override
  Future<void> setTodayBlocked(bool value) async {
    await _settingsBox.put(_isTodayBlockedKey, value);
  }

  @override
  Future<bool> isUnknownBlocked() async {
    return Future.value(
      _settingsBox.get(_isUnknownBlockedKey, defaultValue: false) as bool,
    );
  }

  @override
  Future<void> setUnknownBlocked(bool value) async {
    await _settingsBox.put(_isUnknownBlockedKey, value);
  }

  @override
  Future<bool> isAutoBlockDanger() async {
    return Future.value(
      _settingsBox.get(_isAutoBlockDangerKey, defaultValue: false) as bool,
    );
  }

  @override
  Future<void> setAutoBlockDanger(bool value) async {
    await _settingsBox.put(_isAutoBlockDangerKey, value);
  }

  @override
  Future<bool> isBombCallsBlocked() async {
    return Future.value(
      _settingsBox.get(_isBombCallsBlockedKey, defaultValue: false) as bool,
    );
  }

  @override
  Future<void> setBombCallsBlocked(bool value) async {
    await _settingsBox.put(_isBombCallsBlockedKey, value);
  }

  @override
  Future<int> getBombCallsCount() async {
    // 기본값 0으로 설정
    return Future.value(
      _settingsBox.get(_bombCallsCountKey, defaultValue: 0) as int,
    );
  }

  @override
  Future<void> setBombCallsCount(int count) async {
    await _settingsBox.put(_bombCallsCountKey, count);
  }

  // --- SMS 동기화 타임스탬프 구현 --- (추가)
  @override
  Future<int> getLastSmsSyncTimestamp() async {
    // 기본값 0으로 설정 (최초 실행 시 모든 SMS를 가져오도록)
    return Future.value(
      _settingsBox.get(_lastSmsSyncTimestampKey, defaultValue: 0) as int,
    );
  }

  @override
  Future<void> setLastSmsSyncTimestamp(int timestamp) async {
    await _settingsBox.put(_lastSmsSyncTimestampKey, timestamp);
  }

  // --- 일반 설정 값 접근 구현 (선택적) ---
  // @override
  // Future<T?> getSetting<T>(String key, {T? defaultValue}) async {
  //   return Future.value(_settingsBox.get(key, defaultValue: defaultValue) as T?);
  // }

  // @override
  // Future<void> setSetting<T>(String key, T value) async {
  //   await _settingsBox.put(key, value);
  // }
}
