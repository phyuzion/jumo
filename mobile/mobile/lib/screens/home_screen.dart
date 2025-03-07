// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'dialer_screen.dart';
import 'recent_calls_screen.dart';
import 'contacts_screen.dart';
import 'board_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  // 탭별 화면
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
              // 검색 팝업 이동
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
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dialpad), label: '다이얼러'),
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
