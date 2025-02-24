// lib/main.dart

import 'package:flutter/material.dart';
import 'package:mobile/shared/themes/app_theme.dart';
import 'navigation/app_router.dart';
import 'navigation/navigation_service.dart';
import 'core/controllers/phone_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // 전화 컨트롤러 초기화: CallKit 이벤트 리스너 등록, etc.
  PhoneController().initPhoneLogic();

  runApp(const JumoApp());
}

class JumoApp extends StatelessWidget {
  const JumoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: NavigationService.instance.navigationKey,
      onGenerateRoute: AppRoute.generateRoute,
      initialRoute: AppRoute.splashPage,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
    );
  }
}
