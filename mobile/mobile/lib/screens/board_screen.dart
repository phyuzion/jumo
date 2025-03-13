import 'package:flutter/material.dart';
import 'package:mobile/screens/board_list_view.dart';

class BoardScreen extends StatefulWidget {
  const BoardScreen({Key? key}) : super(key: key);

  @override
  State<BoardScreen> createState() => _BoardScreenState();
}

class _BoardScreenState extends State<BoardScreen> {
  // 0,1,2 중 하나. 기본 0
  int _selectedType = 0;

  // 글쓰기 FAB 클릭
  void _onTapCreate() {
    final type = _selectedType;
    Navigator.pushNamed(context, '/contentCreate', arguments: type).then((res) {
      // 작성 후 돌아오면 refresh
      setState(() {});
    });
  }

  // 드롭다운 변경
  void _onTypeChanged(int? newVal) {
    if (newVal == null) return;
    setState(() => _selectedType = newVal);
  }

  @override
  Widget build(BuildContext context) {
    // 드롭다운 아이템
    const dropdownItems = [
      DropdownMenuItem(value: 0, child: Text('CONTENT_0')),
      DropdownMenuItem(value: 1, child: Text('CONTENT_1')),
      DropdownMenuItem(value: 2, child: Text('CONTENT_2')),
    ];

    return Scaffold(
      appBar: AppBar(
        // 예: SearchScreen 색깔 원한다면:
        backgroundColor: Colors.grey[100],
        toolbarHeight: 40, // 세로 높이 줄이기
        titleSpacing: 0, // 좌우 여백 제거
        centerTitle: false,

        title: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16), // 좌우 패딩
          child: DropdownButton<int>(
            value: _selectedType,
            items: dropdownItems,
            onChanged: _onTypeChanged,

            // 밑줄 제거
            underline: const SizedBox(),
            // 가로 전체 사용
            isExpanded: true,

            // 폰트 스타일
            style: const TextStyle(fontSize: 20, color: Colors.black),

            // 드롭다운 아이콘(아래 화살표)
            icon: const Icon(
              Icons.arrow_drop_down,
              color: Colors.black,
              size: 40,
            ),
            // 펼쳤을 때의 배경색
            dropdownColor: Colors.white,
          ),
        ),
      ),

      body: BoardListView(type: _selectedType),

      floatingActionButton: FloatingActionButton(
        onPressed: _onTapCreate,
        child: const Icon(Icons.add),
      ),
    );
  }
}
