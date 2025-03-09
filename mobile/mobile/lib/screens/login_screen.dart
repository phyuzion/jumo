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

  @override
  void initState() {
    super.initState();
    final box = GetStorage();

    // 1) 내 휴대폰번호 가져오기
    _myNumber = box.read<String>('myNumber') ?? '';

    // 2) 저장된 아이디/비번이 있는지 확인
    final savedId = box.read<String>('savedLoginId');
    final savedPw = box.read<String>('savedPassword');

    if (savedId != null && savedPw != null) {
      // 저장된 아이디/비번이 있다면 자동 로그인 시도
      _autoLogin(savedId, savedPw);
    }
  }

  /// 자동 로그인 시도
  Future<void> _autoLogin(String savedId, String savedPw) async {
    setState(() => _loading = true);
    try {
      if (_myNumber.isEmpty) {
        throw Exception('내 휴대폰번호(myNumber)가 없습니다. 자동로그인 불가');
      }
      await UserApi.userLogin(
        loginId: savedId,
        password: savedPw,
        phoneNumber: _myNumber,
      );
      // 성공 -> 홈으로
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      debugPrint('자동 로그인 실패: $e');
      // 실패 시 그냥 로그인 화면 보여줌
    } finally {
      setState(() => _loading = false);
    }
  }

  /// 로그인 버튼
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

      // userLogin 호출
      await UserApi.userLogin(
        loginId: loginId,
        password: password,
        phoneNumber: _myNumber,
      );
      // 토큰이 GetStorage('accessToken') 에 저장됨

      // "아이디/비번 기억하기" 체크 시 => 저장
      if (_rememberMe) {
        final box = GetStorage();
        box.write('savedLoginId', loginId);
        box.write('savedPassword', password);
      }

      // /home 이동
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
