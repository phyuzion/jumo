// lib/navigation/navigation_service.dart

import 'package:flutter/material.dart';

class NavigationService {
  final GlobalKey<NavigatorState> navigationKey = GlobalKey<NavigatorState>();

  // 라우트 감시자(필요하면)
  final RouteObserver<ModalRoute<void>> routeObserver =
      RouteObserver<ModalRoute<void>>();

  static final NavigationService _instance = NavigationService._internal();
  factory NavigationService() => _instance;
  NavigationService._internal();

  static NavigationService get instance => _instance;

  Future<T?> pushNamed<T extends Object>(
    String routeName, {
    Object? args,
  }) async {
    return navigationKey.currentState?.pushNamed<T>(routeName, arguments: args);
  }

  Future<T?> pushNamedIfNotCurrent<T extends Object>(
    String routeName, {
    Object? args,
  }) async {
    if (!isCurrent(routeName)) {
      return pushNamed(routeName, args: args);
    }
    return null;
  }

  bool isCurrent(String routeName) {
    bool isCurrent = false;
    navigationKey.currentState?.popUntil((route) {
      if (route.settings.name == routeName) {
        isCurrent = true;
      }
      return true;
    });
    return isCurrent;
  }

  void goBack<T extends Object>({T? result}) {
    navigationKey.currentState?.pop<T>(result);
  }
}
