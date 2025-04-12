import 'dart:developer';
import 'package:flutter/material.dart';
// import 'package:get_storage/get_storage.dart'; // 제거
import 'package:hive_ce/hive.dart'; // Hive 추가
import 'package:mobile/graphql/user_api.dart';
import 'package:mobile/graphql/client.dart'; // GraphQLClientManager 추가 (saveLoginCredentials)
import 'package:mobile/services/native_methods.dart'; // <<< 임포트 추가
import 'package:mobile/utils/constants.dart'; // <<< 임포트 추가

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
  bool _rememberMe = true;

  // 비밀번호 보이기/숨기기
  bool _showPassword = false;

  // final box = GetStorage(); // 제거
  Box get _authBox => Hive.box('auth'); // Hive auth Box 사용

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  // 초기 데이터 로드 (수정됨)
  Future<void> _loadInitialData() async {
    // <<< async 추가
    if (!mounted) return;
    setState(() {
      // 로딩 상태 시작
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
        // Hive에 저장
        await _authBox.put('myNumber', normalizedNumber);
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
        // TODO: 사용자에게 오류 알림 또는 재시도 옵션 제공
      }
    } catch (e) {
      log('[LoginScreen] Error getting phone number: $e');
      if (mounted) {
        setState(() {
          _myNumber = '번호 확인 오류';
          _isNumberLoading = false;
        });
        // TODO: 사용자에게 오류 알림
      }
    }

    // 저장된 ID/PW 로드는 그대로 유지
    final savedId = _authBox.get('savedLoginId') as String?;
    final savedPw = _authBox.get('savedPassword') as String?;
    if (savedId != null) _loginIdCtrl.text = savedId;
    if (savedPw != null) _passwordCtrl.text = savedPw;
    _rememberMe = (savedId != null && savedPw != null);
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

      // 로그인 호출
      await UserApi.userLogin(
        loginId: loginId,
        password: password,
        phoneNumber: _myNumber,
      );

      // 아이디/비번 기억하기
      if (_rememberMe) {
        await GraphQLClientManager.saveLoginCredentials(
          loginId,
          password,
          _myNumber,
        );
      } else {
        await _authBox.delete('savedLoginId');
        await _authBox.delete('savedPassword');
      }

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      // 로딩 상태 해제는 try 블록 내부에서 처리하거나 여기서 한 번 더 확인
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
                      Row(
                        children: [
                          Checkbox(
                            value: _rememberMe,
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _rememberMe = val);
                              }
                            },
                          ),
                          const Text('아이디/비번 기억하기'),
                        ],
                      ),
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
