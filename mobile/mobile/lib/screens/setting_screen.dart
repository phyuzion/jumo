// lib/screens/setting_screen.dart
import 'package:flutter/material.dart';
import 'package:mobile/services/native_default_dialer_methods.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

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

  Future<void> _onTapSetDefault() async {
    final ok = await NativeDefaultDialerMethods.requestDefaultDialerManually();
    if (ok) {
      setState(() => _isDefaultDialer = true);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('기본 전화앱 설정 완료')));
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('기본 전화앱 설정 거부됨')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SettingsScreen')),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(_isDefaultDialer ? '현재 이 앱이 기본 전화앱입니다.' : '현재 기본 전화앱이 아닙니다.'),
          if (!_isDefaultDialer)
            ElevatedButton(
              onPressed: _onTapSetDefault,
              child: const Text('기본 전화앱으로 설정'),
            ),
          ElevatedButton(
            onPressed: () => Navigator.pushNamed(context, '/dialer'),
            child: const Text('Go to Dialer'),
          ),
        ],
      ),
    );
  }
}
