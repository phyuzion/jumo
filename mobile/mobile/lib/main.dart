// lib/main.dart
import 'package:flutter/material.dart';
import 'package:mobile/controllers/navigation_controller.dart';
import 'package:mobile/screens/decider_screen.dart';
import 'package:mobile/screens/home_screen.dart';
import 'package:mobile/screens/search_screen.dart';
import 'package:mobile/screens/setting_screen.dart';
import 'package:mobile/screens/dialer_screen.dart';
import 'package:mobile/screens/incoming_call_screen.dart';
import 'package:mobile/screens/on_call_screen.dart';
import 'package:mobile/screens/call_ended_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await NavigationController.init();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      debugShowMaterialGrid: false,
      theme: ThemeData(
        colorScheme: const ColorScheme.light(
          primary: Colors.transparent, // 버튼 색상 블랙
          onPrimary: Colors.black, // 버튼 위 텍스트 화이트
          surface: Colors.transparent, // 카드, 다이얼로그 등의 서피스 색상 화이트
          onSurface: Colors.black, // 서피스 위 텍스트 블랙
        ),
        useMaterial3: true,
      ),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(1.0)), // 텍스트 크기 고정
          child: child!,
        );
      },

      navigatorKey: NavigationController.navKey,
      initialRoute: '/decider',
      routes: {
        '/decider': (_) => const DeciderScreen(),
        '/settings': (_) => const SettingsScreen(),
        '/dialer': (_) => const DialerScreen(), // 현재 완료
        '/incoming': (ctx) {
          final number =
              ModalRoute.of(ctx)?.settings.arguments as String? ?? '';
          return IncomingCallScreen(incomingNumber: number);
        },
        '/onCall': (_) => const OnCallScreen(),
        '/callEnded': (_) => const CallEndedScreen(),

        // 새로 추가하고 있느 화면
        '/home': (_) => const HomeScreen(),
        '/search': (_) => const SearchScreen(),
      },
    );
  }
}
