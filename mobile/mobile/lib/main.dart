import 'package:flutter/material.dart';
import 'package:mobile/services/native_methods.dart';
import 'screens/dialer_screen.dart';
import 'screens/incoming_call_screen.dart';
import 'screens/on_call_screen.dart';
import 'screens/call_ended_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // 안드로이드 -> Flutter 이벤트 수신
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

  runApp(const JumoPhoneApp());
}

void _goToIncomingScreen(String number) {
  // 라우트 이동 + 번호 전달
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

// 전역 NavigatorKey
final GlobalKey<NavigatorState> navKey = GlobalKey<NavigatorState>();

class JumoPhoneApp extends StatelessWidget {
  const JumoPhoneApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Jumo Phone',
      navigatorKey: navKey,
      initialRoute: '/dialer',
      routes: {
        '/dialer': (ctx) => const DialerScreen(),
        '/incoming': (ctx) {
          final args = ModalRoute.of(ctx)?.settings.arguments as String?;
          return IncomingCallScreen(incomingNumber: args ?? '');
        },
        '/onCall': (ctx) => const OnCallScreen(),
        '/callEnded': (ctx) => const CallEndedScreen(),
      },
    );
  }
}
