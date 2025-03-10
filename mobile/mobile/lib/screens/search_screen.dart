// lib/screens/search_screen.dart

import 'package:flutter/material.dart';
import 'package:mobile/utils/constants.dart';
import 'package:mobile/widgets/search_result_widget.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({Key? key}) : super(key: key);

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _textCtrl = TextEditingController();
  final _focusNode = FocusNode();

  // 검색 실행 버튼을 누를 때마다 phoneNumber를 set => SearchResultWidget 로 교체
  String? _searchPhone;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is String) {
        final norm = normalizePhone(args);
        _textCtrl.text = norm;
        setState(() => _searchPhone = norm);
      }
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _textCtrl.dispose();
    super.dispose();
  }

  void _onSubmit(String value) {
    final query = value.trim();
    if (query.isNotEmpty) {
      final normalized = normalizePhone(query);
      setState(() => _searchPhone = normalized);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 상단 검색 AppBar
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: TextField(
          controller: _textCtrl,
          focusNode: _focusNode,
          textInputAction: TextInputAction.search,
          onSubmitted: _onSubmit,
          decoration: const InputDecoration(
            hintText: '전화번호 검색',
            border: InputBorder.none,
          ),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    // 만약 아직 검색 안했으면 안내 문구
    if (_searchPhone == null || _searchPhone!.isEmpty) {
      return const Center(
        child: Text('검색어를 입력하세요.', style: TextStyle(color: Colors.grey)),
      );
    }
    // 이미 입력이 있다면 => SearchResultWidget 로 교체
    return SearchResultWidget(phoneNumber: _searchPhone!);
  }
}
