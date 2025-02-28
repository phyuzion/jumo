import 'package:flutter/material.dart';
import 'package:mobile/screens/call_screen.dart';
import 'package:mobile/screens/on_calling_screen.dart';
import 'screens/dialer_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'JumoPhone',
      initialRoute: '/',
      routes: {
        '/': (ctx) => const DialerScreen(),
        '/call': (ctx) => const CallScreen(),
        '/onCalling': (ctx) => const OnCallingScreen(),
      },
    );
  }
}
