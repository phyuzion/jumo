// lib/screens/login_screen.dart
import 'package:flutter/material.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 심플: 아이디, 비밀번호, 로그인 버튼
    return Scaffold(
      appBar: AppBar(title: const Text('로그인')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            TextField(decoration: const InputDecoration(labelText: '아이디')),
            TextField(
              decoration: const InputDecoration(labelText: '비밀번호'),
              obscureText: true,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                // 로그인 처리 -> 권한 체크 완료 -> HomeScreen 이동
                Navigator.pushReplacementNamed(context, '/home');
              },
              child: const Text('로그인'),
            ),
          ],
        ),
      ),
    );
  }
}
