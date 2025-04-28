import 'package:hive_ce/hive.dart';

// Hive 박스 키 정의 (필요에 따라 수정)
const String _authTokenKey = 'authToken';
const String _myNumberKey = 'myNumber';
const String _savedLoginIdKey = 'savedLoginId';
const String _savedPasswordKey = 'savedPassword';
const String _userIdKey = 'userId';
const String _userNameKey = 'userName';
const String _userRegionKey = 'userRegion';
const String _userGradeKey = 'userGrade';
const String _userValidUntilKey = 'userValidUntil';
const String _loginStatusKey = 'loginStatus';
const String _userTypeKey = 'userType';

/// 인증 관련 데이터 접근을 위한 추상 클래스 (인터페이스)
abstract class AuthRepository {
  /// 저장된 인증 토큰을 가져옵니다. 없으면 null을 반환합니다.
  Future<String?> getToken();

  /// 인증 토큰을 저장합니다.
  Future<void> setToken(String token);

  /// 저장된 인증 토큰을 삭제합니다.
  Future<void> clearToken();

  /// 로그인 상태인지 확인합니다. (토큰 존재 여부 기반)
  Future<bool> isLoggedIn();

  /// 내 전화번호를 저장합니다.
  Future<void> setMyNumber(String number);

  /// 저장된 내 전화번호를 가져옵니다.
  Future<String?> getMyNumber();

  /// 로그인 자격증명(ID, Password)을 저장합니다.
  Future<void> saveCredentials(String id, String password);

  /// 저장된 로그인 자격증명을 가져옵니다. 없으면 null 값을 포함한 Map을 반환합니다.
  Future<Map<String, String?>> getSavedCredentials();

  /// 저장된 로그인 자격증명을 삭제합니다.
  Future<void> clearSavedCredentials();

  /// 저장된 사용자 ID를 가져옵니다.
  Future<String?> getUserId();

  /// 저장된 사용자 이름을 가져옵니다.
  Future<String?> getUserName();

  /// 저장된 사용자 지역을 가져옵니다.
  Future<String?> getUserRegion();

  /// 저장된 사용자 등급을 가져옵니다.
  Future<String?> getUserGrade();

  /// 저장된 사용자 계정 유효 기간을 가져옵니다.
  Future<String?> getUserValidUntil();

  /// 로그인 상태를 저장합니다.
  Future<void> setLoginStatus(bool status);

  /// 사용자 유형을 저장합니다.
  Future<void> setUserType(String type);

  /// 저장된 사용자 ID를 설정합니다.
  Future<void> setUserId(String id);

  /// 저장된 사용자 이름을 설정합니다.
  Future<void> setUserName(String name);

  /// 저장된 사용자 지역을 설정합니다.
  Future<void> setUserRegion(String region);

  /// 저장된 사용자 등급을 설정합니다.
  Future<void> setUserGrade(String grade);

  /// 저장된 사용자 계정 유효 기간을 설정합니다.
  Future<void> setUserValidUntil(String dateString);

  /// 인증 상태 변경을 감지하는 스트림을 제공합니다. (선택적 구현)
  // Stream<bool> get onAuthStateChanged;
}

/// Hive를 사용하여 AuthRepository 인터페이스를 구현하는 클래스
class HiveAuthRepository implements AuthRepository {
  final Box _authBox;

  /// HiveAuthRepository 생성자
  ///
  /// 의존성 주입을 통해 'auth' Box 인스턴스를 받습니다.
  HiveAuthRepository(this._authBox);

  @override
  Future<String?> getToken() async {
    // Hive 박스에서 토큰을 비동기적으로 가져옵니다.
    // Hive는 기본적으로 동기 API를 제공하지만, Repository 패턴에서는
    // 향후 다른 비동기 데이터 소스(예: Secure Storage)로 교체될 가능성을
    // 고려하여 Future를 반환하는 것이 일반적입니다.
    // 즉시 값을 반환하기 위해 Future.value 사용 가능합니다.
    return Future.value(_authBox.get(_authTokenKey) as String?);
  }

  @override
  Future<void> setToken(String token) async {
    await _authBox.put(_authTokenKey, token);
  }

  @override
  Future<void> clearToken() async {
    await _authBox.delete(_authTokenKey);
  }

  @override
  Future<bool> isLoggedIn() async {
    // 토큰 키가 존재하는지 확인하여 로그인 상태를 판단합니다.
    return Future.value(_authBox.containsKey(_authTokenKey));
  }

  @override
  Future<void> setMyNumber(String number) async {
    await _authBox.put(_myNumberKey, number);
  }

  @override
  Future<String?> getMyNumber() async {
    return Future.value(_authBox.get(_myNumberKey) as String?);
  }

  @override
  Future<void> saveCredentials(String id, String password) async {
    await _authBox.put(_savedLoginIdKey, id);
    await _authBox.put(_savedPasswordKey, password);
  }

  @override
  Future<Map<String, String?>> getSavedCredentials() async {
    final id = _authBox.get(_savedLoginIdKey) as String?;
    final password = _authBox.get(_savedPasswordKey) as String?;
    return Future.value({'id': id, 'password': password});
  }

  @override
  Future<void> clearSavedCredentials() async {
    await _authBox.delete(_savedLoginIdKey);
    await _authBox.delete(_savedPasswordKey);
  }

  @override
  Future<String?> getUserId() async {
    return Future.value(_authBox.get(_userIdKey) as String?);
  }

  @override
  Future<String?> getUserName() async {
    return Future.value(_authBox.get(_userNameKey) as String?);
  }

  @override
  Future<String?> getUserRegion() async {
    return Future.value(_authBox.get(_userRegionKey) as String?);
  }

  @override
  Future<String?> getUserGrade() async {
    return Future.value(_authBox.get(_userGradeKey) as String?);
  }

  @override
  Future<String?> getUserValidUntil() async {
    return Future.value(_authBox.get(_userValidUntilKey) as String?);
  }

  @override
  Future<void> setLoginStatus(bool status) async {
    await _authBox.put(_loginStatusKey, status);
  }

  @override
  Future<void> setUserType(String type) async {
    await _authBox.put(_userTypeKey, type);
  }

  @override
  Future<void> setUserId(String id) async {
    await _authBox.put(_userIdKey, id);
  }

  @override
  Future<void> setUserName(String name) async {
    await _authBox.put(_userNameKey, name);
  }

  @override
  Future<void> setUserRegion(String region) async {
    await _authBox.put(_userRegionKey, region);
  }

  @override
  Future<void> setUserGrade(String grade) async {
    await _authBox.put(_userGradeKey, grade);
  }

  @override
  Future<void> setUserValidUntil(String dateString) async {
    await _authBox.put(_userValidUntilKey, dateString);
  }

  // TODO: 인증 상태 변경 스트림 구현 (필요한 경우)
  // Stream<bool> get onAuthStateChanged => _authBox.watch(key: _authTokenKey).map((event) => event.value != null);
}
