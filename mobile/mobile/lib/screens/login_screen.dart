import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart'; // <<< 추가
import 'package:fluttertoast/fluttertoast.dart'; // <<< fluttertoast 임포트 추가
// import 'package:get_storage/get_storage.dart'; // 제거
import 'package:mobile/graphql/user_api.dart';
import 'package:mobile/graphql/client.dart'; // GraphQLClientManager 추가 (saveLoginCredentials)
import 'package:mobile/repositories/auth_repository.dart'; // <<< 추가
import 'package:mobile/services/native_methods.dart'; // <<< 임포트 추가
import 'package:mobile/utils/constants.dart'; // <<< 임포트 추가
import 'package:provider/provider.dart'; // <<< Provider 추가

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _loginIdCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  String _myNumber = '번호 확인중...'; // <<< 초기값 변경
  bool _isNumberLoading = true; // <<< 번호 로딩 상태 추가
  bool _loading = false;

  // "아이디/비번 기억하기" 체크 여부
  // bool _rememberMe = true; // <<< 제거

  // 비밀번호 보이기/숨기기
  bool _showPassword = false;

  // final box = GetStorage(); // 제거
  late AuthRepository _authRepository; // <<< AuthRepository 인스턴스 변수 추가

  @override
  void initState() {
    super.initState();
    // Provider를 통해 AuthRepository 인스턴스 가져오기 (initState에서는 context 사용 불가)
    // WidgetsBinding.instance.addPostFrameCallback 사용
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _authRepository = context.read<AuthRepository>();
      _loadInitialData();
    });
  }

  // 초기 데이터 로드 (수정됨)
  Future<void> _loadInitialData() async {
    if (!mounted) return;
    setState(() {
      _myNumber = '번호 확인중...';
      _isNumberLoading = true;
    });

    try {
      // 네이티브에서 번호 가져오기
      final rawNumber = await NativeMethods.getMyPhoneNumber();
      if (!mounted) return;

      if (rawNumber.isNotEmpty) {
        final normalizedNumber = normalizePhone(rawNumber);
        log('[LoginScreen] My number loaded: $normalizedNumber');
        // AuthRepository 사용하여 저장
        await _authRepository.setMyNumber(normalizedNumber); // <<< 수정
        // 상태 업데이트
        setState(() {
          _myNumber = normalizedNumber;
          _isNumberLoading = false;
        });
      } else {
        log('[LoginScreen] Failed to get phone number (empty).');
        // 저장된 번호가 있는지 확인 (AuthRepository 사용)
        final savedNumber = await _authRepository.getMyNumber(); // <<< 추가
        if (!mounted) return;
        setState(() {
          if (savedNumber != null && savedNumber.isNotEmpty) {
            _myNumber = savedNumber;
            log('[LoginScreen] Loaded saved number: $savedNumber');
          } else {
            _myNumber = '번호 확인 실패';
            log('[LoginScreen] No saved number found either.');
          }
          _isNumberLoading = false;
        });
      }
    } catch (e) {
      log('[LoginScreen] Error getting phone number: $e');
      if (mounted) {
        // 오류 시에도 저장된 번호 확인
        final savedNumber = await _authRepository.getMyNumber(); // <<< 추가
        if (!mounted) return;
        setState(() {
          if (savedNumber != null && savedNumber.isNotEmpty) {
            _myNumber = savedNumber;
            log('[LoginScreen] Loaded saved number after error: $savedNumber');
          } else {
            _myNumber = '번호 확인 오류';
            log('[LoginScreen] No saved number found after error.');
          }
          _isNumberLoading = false;
        });
      }
    }

    // 저장된 ID/PW 로드
    final credentials = await _authRepository.getSavedCredentials();
    if (!mounted) return;
    final savedId = credentials['id'];
    final savedPw = credentials['password'];

    if (savedId != null) _loginIdCtrl.text = savedId;
    if (savedPw != null) _passwordCtrl.text = savedPw;
    // _rememberMe = (savedId != null && savedPw != null); // <<< 제거
    if (mounted) {
      setState(() {}); // 비동기 작업 후 상태 업데이트
    }
  }

  /// 로그인 버튼 or Enter key
  Future<void> _onLoginPressed() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final loginId = _loginIdCtrl.text.trim();
      final password = _passwordCtrl.text.trim();

      if (loginId.isEmpty || password.isEmpty) {
        throw Exception('아이디와 비번을 모두 입력해주세요.');
      }
      if (_myNumber.isEmpty ||
          _myNumber.contains('확인') ||
          _myNumber.contains('오류')) {
        throw Exception('전화번호를 인식할 수 없습니다. 앱 권한을 확인하거나 재시작해주세요.');
      }

      // 로그인 API 호출
      final loginResult = await UserApi.userLogin(
        loginId: loginId,
        password: password,
        phoneNumber: _myNumber,
      );

      if (loginResult != null && loginResult['user'] is Map) {
        final userData = loginResult['user'] as Map<String, dynamic>; // 타입 캐스팅
        final token = loginResult['accessToken'] as String?; // 토큰도 가져옴

        // AuthRepository를 통해 정보 저장
        if (token != null) await _authRepository.setToken(token); // 토큰 저장
        await _authRepository.setUserId(userData['id'] ?? '');
        await _authRepository.setUserName(userData['name'] ?? '');
        await _authRepository.setUserType(userData['userType'] ?? '');
        await _authRepository.setLoginStatus(true);
        await _authRepository.setUserValidUntil(userData['validUntil'] ?? '');
        await _authRepository.setUserRegion(userData['region'] ?? '');
        await _authRepository.setUserGrade(userData['grade'] ?? '');

        log('[LoginScreen] User info saved via AuthRepository after login.');

        // <<< 항상 로그인 정보 저장 >>>
        await _authRepository.saveCredentials(loginId, password);
        log('[LoginScreen] Credentials saved via AuthRepository after login.');
      } else {
        log(
          '[LoginScreen] Login successful but user data format is unexpected.',
        );
      }

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      String errorMessage = '로그인 중 오류가 발생했습니다.';
      if (e is OperationException) {
        if (e.graphqlErrors.isNotEmpty) {
          errorMessage = e.graphqlErrors.first.message;
          log('[LoginScreen] GraphQL Error: $errorMessage');
        } else {
          errorMessage = '서버 연결 중 오류가 발생했습니다.';
          log(
            '[LoginScreen] Network or other OperationException: ${e.linkException}',
          );
        }
      } else {
        errorMessage = e.toString().replaceAll('Exception: ', '');
        log('[LoginScreen] Other Exception: $errorMessage');
      }

      // <<< Fluttertoast 사용으로 변경 >>>
      // if (mounted) {
      //    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMessage)));
      // }
      Fluttertoast.showToast(
        msg: errorMessage,
        toastLength: Toast.LENGTH_SHORT, // LENGTH_LONG도 가능
        gravity: ToastGravity.BOTTOM, // 위치 (CENTER, TOP 등)
        timeInSecForIosWeb: 1, // iOS/Web 표시 시간
        backgroundColor: Colors.redAccent, // 배경색
        textColor: Colors.white, // 글자색
        fontSize: 16.0, // 폰트 크기
      );
    } finally {
      if (mounted && _loading) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('로그인')),
      body:
          _loading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      // 아이디
                      TextField(
                        controller: _loginIdCtrl,
                        decoration: const InputDecoration(labelText: '아이디'),
                        textInputAction: TextInputAction.next,
                      ),
                      // 비밀번호
                      TextField(
                        controller: _passwordCtrl,
                        decoration: InputDecoration(
                          labelText: '비밀번호',
                          suffixIcon: IconButton(
                            icon: Icon(
                              _showPassword
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                            onPressed: () {
                              setState(() {
                                _showPassword = !_showPassword;
                              });
                            },
                          ),
                        ),
                        obscureText: !_showPassword,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _onLoginPressed(),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _onLoginPressed,
                        child: const Text('로그인'),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        _isNumberLoading ? '번호 확인중...' : '내 번호: $_myNumber',
                        style: TextStyle(
                          color:
                              _myNumber.contains('실패') ||
                                      _myNumber.contains('오류')
                                  ? Colors.red
                                  : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
    );
  }
}
