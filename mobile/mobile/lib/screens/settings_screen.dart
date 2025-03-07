// lib/screens/settings_screen.dart
import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 내 폰 번호, 아이디, 이름, 만료일, 비밀번호 변경, 기본전화앱 등록, 로그아웃
    return ListView(
      children: [
        ListTile(
          title: const Text('내 폰 번호'),
          subtitle: const Text('010-xxxx-xxxx'),
        ),
        ListTile(title: const Text('내 아이디'), subtitle: const Text('user123')),
        ListTile(title: const Text('내 이름'), subtitle: const Text('홍길동')),
        ListTile(title: const Text('만료일'), subtitle: const Text('2023-xx-xx')),
        ElevatedButton(
          onPressed: () {
            // 비밀번호 변경
          },
          child: const Text('비밀번호 변경'),
        ),
        ElevatedButton(
          onPressed: () {
            // 기본 전화앱 등록
          },
          child: const Text('기본 전화앱 등록'),
        ),
        ElevatedButton(
          onPressed: () {
            // 로그아웃
            Navigator.pushReplacementNamed(context, '/login');
          },
          child: const Text('로그아웃'),
        ),
      ],
    );
  }
}
