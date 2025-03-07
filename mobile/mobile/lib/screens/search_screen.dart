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
        final normalized = _normalizePhone(args);
        _textController.text = normalized;
      }
      _focusNode.requestFocus();
    });
  }

  /// 전화번호 정규화:
  /// 1) 숫자만 남김 ([^0-9] 제거)
  /// 2) +82 => 맨 앞 '82' 를 '0' 으로 변환 (조건부)
  ///    예) +82-10-1234-5678 => 01012345678
  String _normalizePhone(String raw) {
    // 1) 모두 소문자로
    final lower = raw.toLowerCase().trim();
    // 2) +82 를 우선 처리 -> "82"
    //    간단히 replaceAll
    //    하지만 실제론 "replace +82 => "82", 나중에 처리
    var replaced = lower.replaceAll('+82', '82');

    // 3) 숫자 외 문자를 제거
    //    (공백, -, (, ), 등 모두 제거)
    replaced = replaced.replaceAll(RegExp(r'[^0-9]'), '');

    // 4) 만약 '82'로 시작하면 => '0' + (이후)
    //    예) "8210..." => "010..."
    if (replaced.startsWith('82')) {
      // '82' -> '0'
      replaced = '0${replaced.substring(2)}';
    }

    return replaced;
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
