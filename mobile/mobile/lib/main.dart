// lib/main.dart
import 'package:flutter/material.dart';
import 'package:mobile/controllers/app_controller.dart';
import 'package:mobile/controllers/navigation_controller.dart';
import 'package:mobile/screens/setting_screen.dart';
import 'package:mobile/screens/dialer_screen.dart';
import 'package:mobile/screens/incoming_call_screen.dart';
import 'package:mobile/screens/on_call_screen.dart';
import 'package:mobile/screens/call_ended_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1) NavigationController init => setMethodCallHandler(...) for incoming calls
  await NavigationController.init();

  // 2) 앱 컨트롤러
  final appController = AppController();
  await appController.initializeApp();

  // 3) runApp
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: NavigationController.navKey,
      initialRoute: '/settings',
      routes: {
        '/settings': (_) => const SettingsScreen(),
        '/dialer': (_) => const DialerScreen(),
        '/incoming': (ctx) {
          final number =
              ModalRoute.of(ctx)?.settings.arguments as String? ?? '';
          return IncomingCallScreen(incomingNumber: number);
        },
        '/onCall': (_) => const OnCallScreen(),
        '/callEnded': (_) => const CallEndedScreen(),
      },
    );
  }
}
