import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:mobile/graphql/user_api.dart';
import 'package:mobile/services/native_methods.dart';
import 'package:mobile/utils/constants.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _loginIdCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  String _myNumber = ''; // 내 휴대폰번호
  bool _loading = false;

  // "아이디/비번 기억하기" 체크 여부
  bool _rememberMe = true;

  final box = GetStorage();

  @override
  void initState() {
    _initMyNumber();
    super.initState();
  }

  Future<void> _initMyNumber() async {
    // 네이티브에서 내 번호 가져오기
    final number = await NativeMethods.getMyPhoneNumber();
    log('myNumber=$number');

    // normalizePhone
    _myNumber = normalizePhone(number);
    box.write('myNumber', _myNumber);
    setState(() {});
  }

  /// [로그인] 버튼
  Future<void> _onLoginPressed() async {
    setState(() => _loading = true);
    try {
      final loginId = _loginIdCtrl.text.trim();
      final password = _passwordCtrl.text.trim();
      if (loginId.isEmpty || password.isEmpty) {
        throw Exception('아이디/비번을 입력하세요');
      }
      if (_myNumber.isEmpty) {
        throw Exception('내 휴대폰번호(myNumber)가 없습니다.');
      }

      // 실제 서버 로그인
      await UserApi.userLogin(
        loginId: loginId,
        password: password,
        phoneNumber: _myNumber,
      );

      // 로그인 성공 => 저장
      box.write('loginStatus', true);

      if (_rememberMe) {
        box.write('savedLoginId', loginId);
        box.write('savedPassword', password);
      } else {
        box.remove('savedLoginId');
        box.remove('savedPassword');
      }

      // 홈 이동
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
          _myNumber == ''
              ? const Center(child: Text('전화번호가 없습니다.'))
              : _loading
              ? const Center(child: CircularProgressIndicator())
              : Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    TextField(
                      controller: _loginIdCtrl,
                      decoration: const InputDecoration(labelText: '아이디'),
                    ),
                    TextField(
                      controller: _passwordCtrl,
                      decoration: const InputDecoration(labelText: '비밀번호'),
                      obscureText: true,
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
