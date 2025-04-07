import 'dart:developer';
import 'package:flutter/material.dart';
// import 'package:get_storage/get_storage.dart'; // 제거
import 'package:hive_ce/hive.dart'; // Hive 추가
import 'package:mobile/graphql/user_api.dart';
import 'package:mobile/graphql/client.dart'; // GraphQLClientManager 추가 (saveLoginCredentials)

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _loginIdCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  String _myNumber = ''; // 초기값 설정
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

  // 초기 데이터 로드 (myNumber, savedId/pw)
  void _loadInitialData() {
    _myNumber = _authBox.get('myNumber', defaultValue: '') as String;
    final savedId = _authBox.get('savedLoginId') as String?;
    final savedPw = _authBox.get('savedPassword') as String?;

    // 저장된 ID/PW 있으면 입력 필드에 설정
    if (savedId != null) _loginIdCtrl.text = savedId;
    if (savedPw != null) _passwordCtrl.text = savedPw;

    // 저장된 정보가 있다면 _rememberMe 기본값 true 유지, 없으면 false
    _rememberMe = (savedId != null && savedPw != null);

    // 자동 로그인 로직 제거 (user_api 또는 client 에서 처리)
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
      if (_myNumber.isEmpty) {
        throw Exception('전화번호를 인식할수 없습니다. 앱을 재시작해주세요.');
      }

      // 로그인 호출 (내부에서 Hive에 토큰 저장)
      await UserApi.userLogin(
        loginId: loginId,
        password: password,
        phoneNumber: _myNumber,
      );

      // 아이디/비번 기억하기 체크 시 Hive에 저장
      if (_rememberMe) {
        await GraphQLClientManager.saveLoginCredentials(
          loginId,
          password,
          _myNumber,
        );
      } else {
        // 체크 해제 시 저장된 정보 삭제 (선택적)
        await _authBox.delete('savedLoginId');
        await _authBox.delete('savedPassword');
      }

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('로그인')),
      body:
          _loading
              ? const Center(child: CircularProgressIndicator())
              : Padding(
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
                      '내 번호: $_myNumber',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
    );
  }
}
