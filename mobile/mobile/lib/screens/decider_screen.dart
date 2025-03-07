// lib/screens/decider_screen.dart
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:mobile/controllers/app_controller.dart';
import 'package:mobile/services/native_methods.dart';

class DeciderScreen extends StatefulWidget {
  const DeciderScreen({super.key});

  @override
  State<DeciderScreen> createState() => _DeciderScreenState();
}

class _DeciderScreenState extends State<DeciderScreen> {
  final appController = AppController();

  bool _checking = true; // 권한 체크 중
  bool _allPermsGranted = false;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    setState(() => _checking = true);
    final ok = await appController.checkEssentialPermissions();
    if (ok) {
      if (!mounted) return;
      // 권한 + 초기화 끝 -> 로그인 화면

      final myNumber = await NativeMethods.getMyPhoneNumber();
      log('myNumber=$myNumber');
      GetStorage().write('myNumber', myNumber);

      Navigator.pushReplacementNamed(context, '/login');
    } else {
      // 권한 거부
      setState(() {
        _checking = false;
        _allPermsGranted = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(body: Center(child: Text('권한 확인중...')));
    }

    if (!_allPermsGranted) {
      // 권한 거부 상태 -> 안내 + 재요청
      return Scaffold(
        appBar: AppBar(title: const Text('권한 요청')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('필수 권한이 부족합니다.\n권한을 허용해주세요.'),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _checkPermissions,
                child: const Text('권한 재요청'),
              ),
            ],
          ),
        ),
      );
    }

    // theoretically won't reach here
    return const SizedBox();
  }
}
