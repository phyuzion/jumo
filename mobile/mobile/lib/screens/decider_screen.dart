// lib/screens/decider_screen.dart
import 'dart:developer';

import 'package:flutter/material.dart';
// import 'package:get_storage/get_storage.dart'; // 제거
import 'package:hive_ce/hive.dart'; // Hive 추가
import 'package:mobile/controllers/app_controller.dart';
import 'package:mobile/services/native_methods.dart';
import 'package:mobile/utils/constants.dart';
import 'package:provider/provider.dart';

class DeciderScreen extends StatefulWidget {
  const DeciderScreen({super.key});

  @override
  State<DeciderScreen> createState() => _DeciderScreenState();
}

class _DeciderScreenState extends State<DeciderScreen> {
  bool _checking = true;

  bool _allPermsGranted = false;

  // final box = GetStorage(); // 제거
  Box get _authBox => Hive.box('auth'); // Hive auth Box 사용

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    final appController = context.read<AppController>();
    if (!mounted) return;
    setState(() => _checking = true);
    final ok = await appController.checkEssentialPermissions();

    if (ok) {
      final isLoggedIn =
          _authBox.get('loginStatus', defaultValue: false) as bool;
      if (isLoggedIn) {
        // ... (홈으로 바로 이동)
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        // <<< 바로 로그인 화면으로 이동 >>>
        log('[DeciderScreen] Not logged in, navigating to login.');
        if (!mounted) return; // 추가: 네비게이션 전 마운트 확인
        Navigator.pushReplacementNamed(context, '/login');
      }
    } else {
      // 권한 거부 처리 (기존 유지)
      if (!mounted) return;
      setState(() {
        _checking = false;
        _allPermsGranted = false;
      });
    }
    // <<< 함수 끝에서도 checking 상태 업데이트 (권한 거부 외 경로) >>>
    // 이 부분이 필요할 수 있음 (네비게이션 후에도 위젯이 남아있을 경우 대비)
    // 하지만 pushReplacementNamed 후에는 보통 필요 없음
    // if (mounted && _checking) {
    //    setState(() => _checking = false);
    // }
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
