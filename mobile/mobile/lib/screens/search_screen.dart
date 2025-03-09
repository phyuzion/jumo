// lib/screens/search_screen.dart
import 'package:flutter/material.dart';
import 'package:mobile/graphql/search_api.dart';
import 'package:mobile/models/phone_number_model.dart';
import 'package:mobile/utils/constants.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({Key? key}) : super(key: key);

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _textCtrl = TextEditingController();
  final _focusNode = FocusNode();

  bool _loading = false;
  String? _error;
  PhoneNumberModel? _result;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is String) {
        _textCtrl.text = normalizePhone(args);
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

  Future<void> _onSubmit(String value) async {
    final query = value.trim();
    if (query.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
      _result = null;
    });

    try {
      final normalized = normalizePhone(query);
      final data = await SearchApi.getPhoneNumber(normalized);
      setState(() {
        _result = data; // null 이면 "서버에 기록 없음"
      });
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Text('에러: $_error', style: const TextStyle(color: Colors.red)),
      );
    }
    if (_result == null) {
      return const Center(
        child: Text('검색 결과가 없습니다.', style: TextStyle(color: Colors.grey)),
      );
    }
    // 결과 존재
    return _buildResultView(_result!);
  }

  Widget _buildResultView(PhoneNumberModel model) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '번호: ${model.phoneNumber}',
            style: const TextStyle(fontSize: 18),
          ),
          Text('type: ${model.type}', style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 10),
          const Text(
            '등록된 레코드들:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          if (model.records.isEmpty)
            const Text('레코드가 없습니다.', style: TextStyle(color: Colors.grey))
          else
            ...model.records.map(
              (r) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('userName: ${r.userName} (userType: ${r.userType})'),
                    Text('name: ${r.name}'),
                    Text('memo: ${r.memo}'),
                    Text('type: ${r.type}'),
                    Text('createdAt: ${r.createdAt}'),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // AppBar에 검색 TextField
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
}
