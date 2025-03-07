import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:mobile/controllers/app_controller.dart';
import 'package:mobile/controllers/navigation_controller.dart';
import 'package:mobile/controllers/phone_state_controller.dart';
import 'package:mobile/screens/decider_screen.dart';
import 'package:mobile/screens/login_screen.dart';
import 'package:mobile/screens/home_screen.dart';
import 'package:mobile/screens/search_screen.dart';
import 'package:mobile/screens/dialer_screen.dart';
import 'package:mobile/screens/incoming_call_screen.dart';
import 'package:mobile/screens/on_call_screen.dart';
import 'package:mobile/screens/call_ended_screen.dart';
import 'package:mobile/screens/settings_screen.dart';
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await NavigationController.init(); // 네이티브 이벤트 -> navigation 연동
  await GetStorage.init();

  // 1) phoneStateController
  final phoneStateController = PhoneStateController(
    NavigationController.navKey,
  );

  // 2) appController (의존성으로 phoneStateController 주입)
  final appController = AppController(phoneStateController);

  runApp(
    MultiProvider(
      providers: [
        Provider<PhoneStateController>.value(value: phoneStateController),
        Provider<AppController>.value(value: appController),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: NavigationController.navKey,
      debugShowCheckedModeBanner: false,
      debugShowMaterialGrid: false,
      // 앱 전체 Theme
      theme: ThemeData(
        colorScheme: const ColorScheme.light(
          primary: Colors.black,
          onPrimary: Colors.black,
          surface: Colors.white,
          onSurface: Colors.black,
        ),
        useMaterial3: true,
      ),
      // 텍스트 크기 고정
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(1.0)),
          child: child!,
        );
      },
      initialRoute: '/decider', // 앱 시작은 /decider (권한 체크)
      routes: {
        '/decider': (_) => const DeciderScreen(),
        '/login': (_) => const LoginScreen(),
        '/home': (_) => const HomeScreen(),
        '/search': (_) => const SearchScreen(),
        '/settings': (_) => const SettingsScreen(),
        '/dialer': (_) => const DialerScreen(),
        '/incoming': (ctx) {
          final number =
              ModalRoute.of(ctx)?.settings.arguments as String? ?? '';
          return IncomingCallScreen(incomingNumber: number);
        },
        '/onCall': (_) => const OnCallScreen(),
        '/callEnded': (ctx) {
          final number =
              ModalRoute.of(ctx)?.settings.arguments as String? ?? '';
          return CallEndedScreen(callEndedNumber: number);
        },
      },
    );
  }
}
