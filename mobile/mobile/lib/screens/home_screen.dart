// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:mobile/controllers/app_controller.dart';
import 'package:mobile/services/native_default_dialer_methods.dart';
import 'package:provider/provider.dart';
import 'recent_calls_screen.dart';
import 'contacts_screen.dart';
import 'board_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final _screens = [
    const RecentCallsScreen(),
    const ContactsScreen(),
    const BoardScreen(),
    const SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();

    final appController = context.read<AppController>();
    appController.initializeApp();
    appController.configureBackgroundService();
    appController.startBackgroundService();

    NativeDefaultDialerMethods.notifyNativeAppInitialized();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (idx) => setState(() => _currentIndex = idx),
        type: BottomNavigationBarType.fixed,
        // 스타일 커스터마이징
        backgroundColor: Colors.white,
        elevation: 0, // 윗선 제거
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.grey,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.history), label: '최근기록'),
          BottomNavigationBarItem(icon: Icon(Icons.contacts), label: '연락처'),
          BottomNavigationBarItem(
            icon: Icon(Icons.article_outlined),
            label: '게시판',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: '설정'),
        ],
      ),
    );
  }
}
