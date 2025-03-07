// lib/screens/login_screen.dart
import 'package:flutter/material.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
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
                // 로그인 로직
                // 성공 시 Home 이동
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
