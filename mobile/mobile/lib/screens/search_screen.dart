import 'package:flutter/material.dart';
import 'package:mobile/controllers/search_records_controller.dart';
import 'package:mobile/models/phone_number_model.dart';
import 'package:mobile/models/search_result_model.dart';
import 'package:mobile/models/today_record.dart';
import 'package:mobile/utils/constants.dart';
import 'package:mobile/widgets/search_result_widget.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _textCtrl = TextEditingController();
  bool _loading = false;
  String? _error;
  SearchResultModel? _result; // 검색 결과

  final _focusNode = FocusNode();

  // 검색 실행 버튼을 누를 때마다 phoneNumber를 set => SearchResultWidget 로 교체
  String _searchPhone = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is String) {
        _searchPhone = normalizePhone(args);
        _textCtrl.text = _searchPhone;
        _onSubmit(_searchPhone);
        setState(() {});
      }
      _focusNode.requestFocus();
    });
  }

  void _onSubmit(String num) async {
    final numResult = num.trim();
    if (numResult.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
      _result = null;
    });

    try {
      // 전화번호 검색
      final phoneData = await SearchRecordsController.searchPhone(numResult);

      // 오늘의 레코드 검색
      final todayRecords = await SearchRecordsController.searchTodayRecord(
        numResult,
      );

      setState(() {
        _result = SearchResultModel(
          phoneNumberModel: phoneData,
          todayRecords: todayRecords,
          isNew: phoneData == null,
        );
      });
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _textCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _textCtrl,
          keyboardType: TextInputType.phone,
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

    // 결과가 있다면 -> SearchResultWidget(SearchResultModel)
    return SearchResultWidget(searchResult: _result!);
  }
}
