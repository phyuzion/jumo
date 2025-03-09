import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:mobile/graphql/apis.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _loginIdCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  late final String _myNumber; // 저장해둔 휴대폰번호

  bool _loading = false;

  @override
  void initState() {
    super.initState();
    // GetStorage 에 저장한 myNumber 가져오기
    final box = GetStorage();
    _myNumber = box.read<String>('myNumber') ?? '';
  }

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
      await JumoGraphQLApi.userLogin(
        loginId: loginId,
        password: password,
        phoneNumber: _myNumber,
      );
      // 성공 => 토큰이 GetStorage('accessToken') 에 저장됨

      // 그리고 /home 이동
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
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child:
            _loading
                ? const Center(child: CircularProgressIndicator())
                : Column(
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
