// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:mobile/controllers/app_controller.dart';
import 'dialer_screen.dart';
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
  final appController = AppController();

  @override
  void initState() {
    super.initState();

    appController.initializeApp();
  }

  int _currentIndex = 0;

  final _screens = [
    const DialerScreen(),
    const RecentCallsScreen(),
    const ContactsScreen(),
    const BoardScreen(),
    const SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titleForIndex(_currentIndex)),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              Navigator.pushNamed(context, '/search');
            },
          ),
        ],
      ),
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
          BottomNavigationBarItem(icon: Icon(Icons.dialpad), label: '키패드'),
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

  String _titleForIndex(int idx) {
    switch (idx) {
      case 0:
        return '다이얼러';
      case 1:
        return '최근기록';
      case 2:
        return '연락처';
      case 3:
        return '게시판';
      case 4:
        return '설정';
    }
    return '';
  }
}
