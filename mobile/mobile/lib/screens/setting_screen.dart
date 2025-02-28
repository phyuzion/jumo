// lib/screens/settings_screen.dart

import 'package:flutter/material.dart';
import 'package:mobile/services/native_default_dialer_methods.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isDefaultDialer = false;

  @override
  void initState() {
    super.initState();
    _checkDefaultDialer();
  }

  Future<void> _checkDefaultDialer() async {
    final isDef = await NativeDefaultDialerMethods.isDefaultDialer();
    setState(() => _isDefaultDialer = isDef);
  }

  Future<void> _onTapSetDefaultDialer() async {
    final ok = await NativeDefaultDialerMethods.requestDefaultDialerManually();
    if (ok) {
      setState(() => _isDefaultDialer = true);
    } else {
      // 실패/거부
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('기본 전화앱 설정이 거부되었습니다.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _isDefaultDialer ? '현재 이 앱이 기본 전화앱입니다.' : '기본 전화앱이 아닙니다.',
              style: const TextStyle(fontSize: 20),
            ),
            const SizedBox(height: 20),
            if (!_isDefaultDialer)
              ElevatedButton(
                onPressed: _onTapSetDefaultDialer,
                child: const Text('기본 전화앱으로 설정'),
              )
            else
              const Text('이미 설정되었습니다.'),
          ],
        ),
      ),
    );
  }
}
