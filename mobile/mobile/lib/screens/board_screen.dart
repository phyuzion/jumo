// lib/screens/board_screen.dart
import 'package:flutter/material.dart';
import 'package:mobile/screens/board_tab_view.dart';

class BoardScreen extends StatefulWidget {
  const BoardScreen({Key? key}) : super(key: key);

  @override
  State<BoardScreen> createState() => _BoardScreenState();
}

class _BoardScreenState extends State<BoardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _tabs = const [
    Tab(text: 'CONTENT_0'),
    Tab(text: 'CONTENT_1'),
    Tab(text: 'CONTENT_2'),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  // 글쓰기 FAB 클릭 => 현재 탭 index를 함께 넘김
  void _onTapCreate() {
    final type = _tabController.index;
    Navigator.pushNamed(context, '/contentCreate', arguments: type).then((res) {
      // 새로고침 or setState
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('게시판(Quill)'),
        bottom: TabBar(controller: _tabController, tabs: _tabs),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          BoardTabView(type: 0),
          BoardTabView(type: 1),
          BoardTabView(type: 2),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _onTapCreate,
        child: const Icon(Icons.add),
      ),
    );
  }
}
