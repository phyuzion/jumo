import 'package:flutter/material.dart';
import 'package:mobile/screens/board_list_view.dart';
import 'package:mobile/widgets/dropdown_menus_widet.dart';

class BoardScreen extends StatefulWidget {
  const BoardScreen({super.key});

  @override
  State<BoardScreen> createState() => _BoardScreenState();
}

class _BoardScreenState extends State<BoardScreen> {
  // GlobalKey 로 BoardListViewState 조작
  final GlobalKey<BoardListViewState> _boardListKey = GlobalKey();

  // 드롭다운 아이템 리스트
  final List<DropdownMenuItem<String>> _dropdownItems = [
    const DropdownMenuItem(value: '공지사항', child: Text('공지사항')),
    const DropdownMenuItem(value: '익명', child: Text('익명')),
  ];
  String _selectedType = '공지사항'; // 기본값을 '공지사항'으로 설정

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
    if (!mounted) return;
    setState(() => _selectedType = newVal);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(40),
        child: AppBar(
          title: DropdownButton<String>(
            value: _selectedType,
            items: _dropdownItems,
            onChanged: _onTypeChanged,
            underline: const SizedBox(),
            isExpanded: true,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.black,
            ),
            icon: const Icon(
              Icons.arrow_drop_down,
              color: Colors.black,
              size: 24,
            ),
            dropdownColor: Colors.white,
          ),
          actions: const [DropdownMenusWidget()],
        ),
      ),
      // (1) BoardListView에 GlobalKey 전달
      body: BoardListView(key: _boardListKey, type: _selectedType),
      // 익명 게시판일 때만 FAB 표시
      floatingActionButton:
          _selectedType == '익명'
              ? FloatingActionButton(
                onPressed: _onTapCreate,
                child: const Icon(Icons.add),
              )
              : null,

      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
    );
  }
}
