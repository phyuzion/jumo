// lib/screens/decider_screen.dart
import 'package:flutter/material.dart';
import 'package:mobile/controllers/app_controller.dart';

class DeciderScreen extends StatefulWidget {
  const DeciderScreen({Key? key}) : super(key: key);

  @override
  State<DeciderScreen> createState() => _DeciderScreenState();
}

class _DeciderScreenState extends State<DeciderScreen> {
  final appController = AppController();

  bool _checking = true; // 초기 권한 체크 중
  bool _allPermsGranted = false; // 권한 결과
  bool _initDone = false; // 앱 초기화(번호 등) 완료 여부

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    setState(() {
      _checking = true; // 체크 중
    });
    final ok = await appController.checkEssentialPermissions();
    if (ok) {
      // 권한 OK → 앱 초기화
      await appController.initializeApp();
      setState(() {
        _initDone = true;
        _allPermsGranted = true;
      });
      // 이동
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/settings');
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

    if (_allPermsGranted) {
      // 이미 권한 OK + initDone => 곧 /settings 이동,
      // 혹은 그냥 빈 화면
      return const Scaffold(body: Center(child: Text('권한 및 초기화 OK, 이동중...')));
    } else {
      // 권한 거부 상태 → "권한 다시 요청" 버튼
      return Scaffold(
        appBar: AppBar(title: const Text('권한 요청')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('필수 권한이 부족합니다.\n권한을 허용해 주세요.'),
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
  }
}
