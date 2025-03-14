import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:mobile/graphql/user_api.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _loginIdCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  late final String _myNumber; // 내 휴대폰번호
  bool _loading = false;

  // "아이디/비번 기억하기" 체크 여부
  bool _rememberMe = true;

  // 비밀번호 보이기/숨기기
  bool _showPassword = false;

  final box = GetStorage();

  @override
  void initState() {
    super.initState();

    // 1) 내 휴대폰번호 가져오기
    _myNumber = box.read<String>('myNumber') ?? '';

    // 2) 저장된 아이디/비번이 있는지 확인
    final savedId = box.read<String>('savedLoginId');
    final savedPw = box.read<String>('savedPassword');

    if (savedId != null && savedPw != null) {
      // 자동 로그인 로직이 필요하다면 주석 해제
      // _autoLogin(savedId, savedPw);
    }
  }

  /// 로그인 버튼 or Enter key
  Future<void> _onLoginPressed() async {
    setState(() => _loading = true);
    try {
      final loginId = _loginIdCtrl.text.trim();
      final password = _passwordCtrl.text.trim();

      // 아이디/비번 체크
      if (loginId.isEmpty || password.isEmpty) {
        throw Exception('아이디와 비번을 모두 입력해주세요.');
      }

      // 전화번호 체크
      if (_myNumber.isEmpty) {
        throw Exception('전화번호를 인식할수 없습니다.');
      }

      // 로그인 호출
      await UserApi.userLogin(
        loginId: loginId,
        password: password,
        phoneNumber: _myNumber,
      );

      // 아이디/비번 기억하기
      if (_rememberMe) {
        box.write('savedLoginId', loginId);
        box.write('savedPassword', password);
      }

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      setState(() => _loading = false);
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
