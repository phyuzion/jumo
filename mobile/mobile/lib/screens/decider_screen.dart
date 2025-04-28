// lib/screens/decider_screen.dart
import 'dart:developer';

import 'package:flutter/material.dart';
// import 'package:get_storage/get_storage.dart'; // 제거
// import 'package:hive_ce/hive.dart'; // <<< 제거
import 'package:mobile/controllers/app_controller.dart';
import 'package:mobile/repositories/auth_repository.dart'; // <<< 추가
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

  bool _allPermsGranted = false; // 권한 상태를 명시적으로 관리 (기존 로직에 없어서 추가)

  // final box = GetStorage(); // 제거
  // Box get _authBox => Hive.box('auth'); // <<< 제거

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    final appController = context.read<AppController>();
    final authRepository =
        context.read<AuthRepository>(); // <<< AuthRepository 가져오기

    if (!mounted) return;
    setState(() => _checking = true);
    final ok = await appController.checkEssentialPermissions();

    if (ok) {
      // 권한 OK -> 로그인 상태 확인
      final isLoggedIn =
          await authRepository.isLoggedIn(); // <<< AuthRepository 사용
      if (isLoggedIn) {
        log('[DeciderScreen] Logged in, navigating to home.');
        if (!mounted) return; // 추가: 네비게이션 전 마운트 확인
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        log('[DeciderScreen] Not logged in, navigating to login.');
        if (!mounted) return; // 추가: 네비게이션 전 마운트 확인
        Navigator.pushReplacementNamed(context, '/login');
      }
    } else {
      // 권한 거부 처리
      if (!mounted) return;
      setState(() {
        _checking = false;
        _allPermsGranted = false;
      });
    }
    // 함수가 끝나면 checking 상태를 false로 설정 (모든 경로에서)
    // Note: pushReplacementNamed 후에는 이 위젯이 unmount될 수 있으므로
    // setState 호출 전에 mounted 확인이 필수적입니다.
    if (mounted && _checking) {
      setState(() => _checking = false);
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
