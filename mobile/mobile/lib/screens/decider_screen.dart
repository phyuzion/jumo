// lib/screens/decider_screen.dart
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
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

  final box = GetStorage();

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
      if (box.read('loginStatus') != null && box.read('loginStatus') == true) {
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        final myNumber = await NativeMethods.getMyPhoneNumber();
        log('myNumber=$myNumber');
        if (myNumber == '') {
          //kill app
        }
        final myRealnumber = normalizePhone(myNumber);
        box.write('myNumber', myRealnumber);

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
