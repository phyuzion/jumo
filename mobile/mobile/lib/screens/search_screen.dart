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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is String) {
        _textController.text = args;
      }
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSubmitSearch(String query) {
    // TODO: 검색 로직
    debugPrint('Searching for $query');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 25),
          onPressed: () => Navigator.pop(context),
        ),
        title: TextField(
          focusNode: _focusNode,
          controller: _textController,
          style: const TextStyle(
            fontSize: 22, // TextField 폰트 크기
          ),
          decoration: const InputDecoration(
            hintText: '전화번호 검색',
            hintStyle: TextStyle(
              fontSize: 22, // 힌트 텍스트 크기
              color: Colors.grey,
            ),
            border: InputBorder.none,
          ),
          textInputAction: TextInputAction.search,
          onSubmitted: _onSubmitSearch,
        ),
      ),
      body: Center(
        child: Text(
          '최근 검색 내용이 없습니다',
          style: TextStyle(
            fontSize: 18, // 본문 폰트 크기
            color: Colors.grey[600],
          ),
        ),
      ),
    );
  }
}
