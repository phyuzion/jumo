import 'package:flutter/material.dart';
import 'package:mobile/screens/board_list_view.dart';
import 'package:mobile/widgets/dropdown_menus_widet.dart';

class BoardScreen extends StatefulWidget {
  const BoardScreen({Key? key}) : super(key: key);

  @override
  State<BoardScreen> createState() => _BoardScreenState();
}

class _BoardScreenState extends State<BoardScreen> {
  // 0,1,2 중 하나. 기본 0
  String _selectedType = '0';

  // GlobalKey 로 BoardListViewState 조작
  final GlobalKey<BoardListViewState> _boardListKey = GlobalKey();

  // 글쓰기 FAB 클릭
  void _onTapCreate() {
    final type = _selectedType;
    // => '/contentCreate' 에 type 전달
    Navigator.pushNamed(context, '/contentCreate', arguments: type).then((res) {
      // 작성 후 돌아옴 -> res == true 이면 재조회
      if (res == true) {
        _boardListKey.currentState?.refresh();
      }
    });
  }

  // 드롭다운 변경
  void _onTypeChanged(String? newVal) {
    if (newVal == null) return;
    setState(() => _selectedType = newVal);
  }

  @override
  Widget build(BuildContext context) {
    // 드롭다운 아이템
    const dropdownItems = [
      DropdownMenuItem(value: '0', child: Text('CONTENT_0')),
      DropdownMenuItem(value: '1', child: Text('CONTENT_1')),
      DropdownMenuItem(value: '2', child: Text('CONTENT_2')),
    ];

    return Scaffold(
      appBar: AppBar(
        title: DropdownButton<String>(
          value: _selectedType,
          items: dropdownItems,
          onChanged: _onTypeChanged,
          underline: const SizedBox(), // 밑줄 제거
          isExpanded: true, // 가로로 꽉 차게
          style: const TextStyle(fontSize: 20, color: Colors.black),
          icon: const Icon(
            Icons.arrow_drop_down,
            color: Colors.black,
            size: 40,
          ),
          dropdownColor: Colors.white,
        ),
        actions: [const DropdownMenusWidget()],
      ),
      // (1) BoardListView에 GlobalKey 전달
      body: BoardListView(key: _boardListKey, type: _selectedType),
      floatingActionButton: FloatingActionButton(
        onPressed: _onTapCreate,
        child: const Icon(Icons.add),
      ),
    );
  }
}
