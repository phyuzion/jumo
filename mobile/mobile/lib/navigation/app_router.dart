// lib/navigation/app_router.dart

import 'package:flutter/material.dart';
import '../modules/splash/splash_page.dart';
import '../modules/home/home_page.dart';
import '../modules/phone/incoming_call_page.dart';
import '../modules/phone/calling_page.dart';

class AppRoute {
  static const splashPage = '/splash';
  static const homePage = '/home';
  static const incomingCallPage = '/incoming_call';
  static const callingPage = '/calling';

  static Route<Object>? generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case splashPage:
        return MaterialPageRoute(builder: (_) => const SplashPage());
      case homePage:
        return MaterialPageRoute(builder: (_) => const HomePage());
      case incomingCallPage:
        final data = settings.arguments;
        if (data is Map<String, dynamic>) {
          return MaterialPageRoute(
            builder: (_) => IncomingCallPage(eventData: data),
          );
        }
        return _errorRoute();
      case callingPage:
        return MaterialPageRoute(builder: (_) => const CallingPage());
      default:
        return _errorRoute();
    }
  }

  static Route<Object> _errorRoute() {
    return MaterialPageRoute(
      builder:
          (_) => const Scaffold(body: Center(child: Text('Unknown route'))),
    );
  }
}
