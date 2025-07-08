import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart'; // <<< 추가
import 'package:fluttertoast/fluttertoast.dart'; // <<< fluttertoast 임포트 추가
// import 'package:get_storage/get_storage.dart'; // 제거
import 'package:mobile/graphql/user_api.dart';
// import 'package:mobile/graphql/client.dart'; // GraphQLClientManager는 UserApi 내부에서 사용될 것으로 가정
import 'package:mobile/repositories/auth_repository.dart'; // <<< 추가
import 'package:mobile/services/native_methods.dart'; // <<< 임포트 추가
import 'package:mobile/utils/constants.dart'; // <<< 임포트 추가
import 'package:provider/provider.dart'; // <<< Provider 추가
import 'package:mobile/controllers/app_controller.dart'; // AppController import

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
        // 상태 업데이트
        setState(() {
          _myNumber = normalizedNumber;
          _isNumberLoading = false;
        });
      } else {
        log('[LoginScreen] Failed to get phone number (empty).');
        setState(() {
          _myNumber = '번호 확인 실패';
          _isNumberLoading = false;
        });
      }
    } catch (e) {
      log('[LoginScreen] Error getting phone number: $e');
      if (mounted) {
        setState(() {
          _myNumber = '번호 확인 오류';
          _isNumberLoading = false;
        });
      }
    }

    // 저장된 ID/PW 로드
    final credentials = await _authRepository.getSavedCredentials();
    if (!mounted) return;
    final savedId = credentials['savedLoginId'];
    final savedPw = credentials['password'];

    if (savedId != null) _loginIdCtrl.text = savedId;
    if (savedPw != null) _passwordCtrl.text = savedPw;
    if (mounted) {
      setState(() {}); // 비동기 작업 후 상태 업데이트
    }
  }

  /// 로그인 버튼 or Enter key
  Future<void> _onLoginPressed() async {
    if (!mounted) return;
    setState(() => _loading = true);

    // <<< 최소한의 변경 시작: 로그인 시도 직전 네이티브에서 전화번호 다시 가져오기 >>>
    if (mounted) {
      // 번호 재확인 시도 전, UI에 로딩 상태를 잠시 반영할 수 있도록 설정
      // (매우 짧은 순간일 수 있음)
      setState(() {
        _isNumberLoading = true;
      });
    }
    try {
      log(
        '[LoginScreen][OnLoginPressed] Attempting to refresh phone number from native.',
      );
      final String rawNewNumber = await NativeMethods.getMyPhoneNumber();
      if (mounted) {
        // 비동기 작업 후 mounted 상태 재확인
        if (rawNewNumber.isNotEmpty) {
          final String normalizedNewNumber = normalizePhone(rawNewNumber);
          log(
            '[LoginScreen][OnLoginPressed] Refreshed phone number: $normalizedNewNumber',
          );
          setState(() {
            _myNumber = normalizedNewNumber; // 내부 상태 업데이트
            _isNumberLoading = false; // 로딩 완료
          });
        } else {
          log(
            '[LoginScreen][OnLoginPressed] Failed to refresh from native (got empty). Using current number: $_myNumber',
          );
          // 네이티브에서 못가져왔거나 비어있다면, 기존 _myNumber 유지.
          // 이 경우 _isNumberLoading은 false로 설정하여 확인 시도가 끝났음을 알림.
          setState(() {
            _isNumberLoading = false;
          });
        }
      }
    } catch (e) {
      log(
        '[LoginScreen][OnLoginPressed] Error refreshing phone number: $e. Using current number: $_myNumber',
      );
      if (mounted) {
        setState(() {
          _isNumberLoading = false; // 에러 시에도 로딩 상태는 해제
        });
      }
    }
    // <<< 최소한의 변경 끝 >>>

    try {
      final loginId = _loginIdCtrl.text.trim();
      final password = _passwordCtrl.text.trim();

      if (loginId.isEmpty || password.isEmpty) {
        throw Exception('아이디와 비번을 모두 입력해주세요.');
      }

      // 전화번호 유효성 검사 (위에서 _myNumber가 업데이트되었을 수 있음)
      if (_myNumber.isEmpty ||
          _myNumber.contains('확인') || // "번호 확인중..." 또는 초기 "번호 확인 실패/오류"
          _myNumber.contains('오류') ||
          _myNumber.contains('실패')) {
        Fluttertoast.showToast(
          msg: '전화번호를 인식할 수 없습니다. 앱 권한을 확인하거나 재시작해주세요.',
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.redAccent,
          textColor: Colors.white,
          fontSize: 16.0,
        );
        if (mounted) {
          // return 전에 로딩 상태 해제
          setState(() => _loading = false);
        }
        return;
      }

      // 로그인 API 호출 (최신 _myNumber 사용)
      final loginResult = await UserApi.userLogin(
        loginId: loginId,
        password: password,
        phoneNumber: _myNumber,
      );

      // 로그인 성공 조건 강화: loginResult, user 데이터, accessToken 모두 null이 아니어야 함
      if (loginResult != null &&
          loginResult['user'] is Map &&
          loginResult['accessToken'] != null) {
        final userData = loginResult['user'] as Map<String, dynamic>;
        final token = loginResult['accessToken'] as String; // Non-null로 처리

        // AuthRepository를 통해 정보 저장
        await _authRepository.setToken(token);
        await _authRepository.setUserId(userData['id'] ?? '');
        await _authRepository.setUserName(userData['name'] ?? '');
        await _authRepository.setUserType(userData['userType'] ?? '');
        await _authRepository.setLoginStatus(true); // 로그인 상태 true로 설정
        await _authRepository.setUserValidUntil(userData['validUntil'] ?? '');
        await _authRepository.setUserRegion(userData['region'] ?? '');
        await _authRepository.setUserGrade(userData['grade'] ?? '');

        log('[LoginScreen] User info saved via AuthRepository after login.');

        // <<< 항상 로그인 정보 저장 >>>
        await _authRepository.saveCredentials(loginId, password);
        log('[LoginScreen] Credentials saved via AuthRepository after login.');

        // 저장된 크레덴셜 확인
        final savedCredentials = await _authRepository.getSavedCredentials();
        if (savedCredentials['savedLoginId'] != loginId ||
            savedCredentials['password'] != password) {
          log(
            '[LoginScreen] Warning: Saved credentials do not match login credentials',
          );
          throw Exception('로그인 정보 저장 중 오류가 발생했습니다.');
        }
        log('[LoginScreen] Verified saved credentials match login credentials');

        if (!mounted) return;
        // 홈으로 가기 전에 AppController를 통해 연락처 로드 시작
        // DeciderScreen에서 이미 권한을 확인하고 넘어왔으므로, 여기서는 로그인 성공이 주 조건
        log('[LoginScreen] Login successful. Triggering contacts load.');
        await context.read<AppController>().triggerContactsLoadIfReady();
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        // loginResult가 null이거나 user 데이터가 없는 경우도 성공으로 간주하지 않음 (토큰 없을 수 있음)
        log(
          '[LoginScreen] Login failed or response data/token is null/unexpected. Result: $loginResult',
        );
        throw Exception('로그인에 실패했습니다. 아이디 또는 비밀번호를 확인해주세요.'); // 사용자에게 더 명확한 메시지
      }
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
