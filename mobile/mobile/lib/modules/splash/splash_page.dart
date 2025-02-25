// lib/modules/splash/splash_page.dart

import 'package:flutter/material.dart';
import 'package:mobile/core/controllers/phone_controller.dart';
import 'package:mobile/core/services/phone_service.dart';
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

    // 2) PhoneService 채널 초기화
    await PhoneService.initChannel();

    // 3) start phone state listener
    await PhoneService.startPhoneStateListener();

    // 4) 내 번호 get -> store
    //await PhoneService.storeMyPhoneNumber();

    // 5) callkit event init
    PhoneController().initPhoneLogic();

    // 2) (선택) 기본 전화앱인지 확인
    final isDef = await DefaultDialerService.isDefaultDialer();
    if (!isDef) {
      await DefaultDialerService.setDefaultDialer();
    }

    // 6) goto Home
    await Future.delayed(const Duration(seconds: 1));
    NavigationService.instance.pushNamed(AppRoute.homePage);
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
