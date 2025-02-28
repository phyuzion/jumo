// lib/main.dart
import 'package:flutter/material.dart';
import 'package:mobile/controllers/navigation_controller.dart';
import 'package:mobile/screens/decider_screen.dart';
import 'package:mobile/screens/setting_screen.dart';
import 'package:mobile/screens/dialer_screen.dart';
import 'package:mobile/screens/incoming_call_screen.dart';
import 'package:mobile/screens/on_call_screen.dart';
import 'package:mobile/screens/call_ended_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 네비 컨트롤러 init => setMethodCallHandler
  await NavigationController.init();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: NavigationController.navKey,
      initialRoute: '/decider',
      routes: {
        '/decider': (_) => const DeciderScreen(),
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
