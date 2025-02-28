// lib/main.dart
import 'package:flutter/material.dart';
import 'package:mobile/controller.dart/app_controller.dart';
import 'package:mobile/services/native_methods.dart';
import 'screens/dialer_screen.dart';
import 'screens/incoming_call_screen.dart';
import 'screens/on_call_screen.dart';
import 'screens/call_ended_screen.dart';

// 전역
final GlobalKey<NavigatorState> navKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 안드로이드 -> Flutter 이벤트
  NativeMethods.setMethodCallHandler((call) async {
    switch (call.method) {
      case 'onIncomingNumber':
        final number = call.arguments as String;
        _goToIncomingScreen(number);
        break;
      case 'onCallEnded':
        _goToCallEnded();
        break;
    }
  });

  // 앱 초기화 (my_number 불러오기, 로그인 등)
  final appController = AppController();
  await appController.initializeApp();

  runApp(const JumoPhoneApp());
}

void _goToIncomingScreen(String number) {
  final ctx = navKey.currentContext;
  if (ctx != null) {
    Navigator.of(ctx).pushNamed('/incoming', arguments: number);
  }
}

void _goToCallEnded() {
  final ctx = navKey.currentContext;
  if (ctx != null) {
    Navigator.of(ctx).pushNamed('/callEnded');
  }
}

class JumoPhoneApp extends StatelessWidget {
  const JumoPhoneApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navKey,
      initialRoute: '/dialer',
      routes: {
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
