import 'package:flutter/material.dart';
import 'package:mobile/screens/board_list_view.dart';
import 'package:mobile/widgets/dropdown_menus_widet.dart';
import 'package:mobile/graphql/common_api.dart';

class BoardScreen extends StatefulWidget {
  const BoardScreen({super.key});

  @override
  State<BoardScreen> createState() => _BoardScreenState();
}

class _BoardScreenState extends State<BoardScreen> {
  // GlobalKey 로 BoardListViewState 조작
  final GlobalKey<BoardListViewState> _boardListKey = GlobalKey();

  // 드롭다운 아이템 리스트
  List<DropdownMenuItem<String>> _dropdownItems = [];
  String _selectedType = '공지사항'; // 기본값을 '공지사항'으로 설정

  @override
  void initState() {
    super.initState();
    _initializeDropdownItems();
  }

  // 드롭다운 아이템 초기화
  Future<void> _initializeDropdownItems() async {
    try {
      final regions = await CommonApi.getRegions();

      setState(() {
        // 공지사항을 첫 번째 아이템으로 추가
        _dropdownItems = [
          const DropdownMenuItem(value: '공지사항', child: Text('공지사항')),
          // 가져온 지역 리스트 추가
          ...regions.map(
            (region) => DropdownMenuItem(
              value: region['name'],
              child: Text(region['name']),
            ),
          ),
          // 익명을 마지막 아이템으로 추가
          const DropdownMenuItem(value: '익명', child: Text('익명')),
        ];
      });
    } catch (e) {
      // 에러 발생시 기본 아이템으로 설정
      setState(() {
        _dropdownItems = [
          const DropdownMenuItem(value: '공지사항', child: Text('공지사항')),
          const DropdownMenuItem(value: '익명', child: Text('익명')),
        ];
      });
    }
  }

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
    return Scaffold(
      appBar: AppBar(
        title: DropdownButton<String>(
          value: _selectedType,
          items: _dropdownItems,
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
