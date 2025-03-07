import 'package:flutter/material.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _textController = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // 화면 빌드가 끝난 후에 focus 주기
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // AppBar: leading = 뒤로가기, title = TextField
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: TextField(
          focusNode: _focusNode,
          controller: _textController,
          decoration: const InputDecoration(
            hintText: '전화번호 검색',
            border: InputBorder.none,
          ),

          textInputAction: TextInputAction.search,
          //onSubmitted: (value) => _doSearch(value),
        ),
      ),
      body: Center(
        child: Text(
          '최근 검색 내용이 없습니다',
          style: TextStyle(fontSize: 16, color: Colors.grey[600]),
        ),
      ),
    );
  }
}
