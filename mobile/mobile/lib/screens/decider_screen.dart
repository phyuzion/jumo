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
      // Hive에서 loginStatus 확인
      final isLoggedIn =
          _authBox.get('loginStatus', defaultValue: false) as bool;
      if (isLoggedIn) {
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        String myNumber = '';
        try {
          myNumber = await NativeMethods.getMyPhoneNumber();
        } catch (e) {
          log('[DeciderScreen] Failed to get phone number: $e');
          // 번호 못 가져올 시 예외 처리 (예: 에러 메시지 표시 후 앱 종료)
        }

        log('myNumber=$myNumber');
        if (myNumber.isEmpty) {
          // TODO: 번호 없을 시 처리 (예: 사용자 안내 후 종료)
          log('[DeciderScreen] Phone number is empty.');
          // SystemNavigator.pop(); // 앱 종료 예시
          // 임시로 로그인 화면으로 이동 (개선 필요)
          Navigator.pushReplacementNamed(context, '/login');
          return;
        }

        final myRealnumber = normalizePhone(myNumber);
        // Hive에 myNumber 저장
        await _authBox.put('myNumber', myRealnumber);

        Navigator.pushReplacementNamed(context, '/login');
      }
    } else {
      // 권한 거부
      if (!mounted) return;
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
