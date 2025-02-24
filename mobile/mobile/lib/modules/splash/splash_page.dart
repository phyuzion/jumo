// lib/modules/splash/splash_page.dart

import 'package:flutter/material.dart';
import '../../../navigation/app_router.dart';
import '../../../navigation/navigation_service.dart';
import '../../../core/services/permission_service.dart';
import '../../../core/services/default_dialer_service.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    _initProcess();
  }

  Future<void> _initProcess() async {
    // 1) 권한 요청
    await PermissionService.requestNecessaryPermissions();

    // 2) (선택) 기본 전화앱인지 확인
    // final isDef = await DefaultDialerService.isDefaultDialer();
    // if (!isDef) {
    //   // await DefaultDialerService.setDefaultDialer();
    // }

    // 3) 잠깐 대기 후 Home으로
    await Future.delayed(const Duration(seconds: 1));
    _goHome();
  }

  void _goHome() {
    NavigationService.instance.pushNamed(AppRoute.homePage);
    // or
    // Navigator.pushReplacementNamed(context, AppRoute.homePage);
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
