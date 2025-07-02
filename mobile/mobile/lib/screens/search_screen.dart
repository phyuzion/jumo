import 'package:flutter/material.dart';
import 'package:mobile/controllers/search_records_controller.dart';
import 'package:mobile/models/search_result_model.dart';
import 'package:mobile/utils/constants.dart';
import 'package:mobile/widgets/search_result_widget.dart';
import 'package:provider/provider.dart';
import 'package:mobile/controllers/contacts_controller.dart';
import 'package:mobile/models/phone_book_model.dart';
import 'dart:developer';
import 'package:graphql_flutter/graphql_flutter.dart';

class SearchScreen extends StatefulWidget {
  final bool isRequested;
  const SearchScreen({super.key, this.isRequested = false});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _textCtrl = TextEditingController();
  bool _loading = false;
  String? _error;
  SearchResultModel? _result;
  final _focusNode = FocusNode();
  late SearchRecordsController _searchController;

  @override
  void initState() {
    super.initState();

    // Provider에서 SearchRecordsController 가져오기 시도
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        _searchController = Provider.of<SearchRecordsController>(
          context,
          listen: false,
        );
      } catch (e) {
        // Provider에 등록되지 않은 경우 새로 생성
        _searchController = SearchRecordsController();
        log('[SearchScreen] 새로운 SearchRecordsController 인스턴스 생성');
      }

      bool hasInitialQuery = false;

      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map<String, dynamic>) {
        final initialNum = args['number'] as String?;
        if (initialNum != null) {
          final normalizedNum = normalizePhone(initialNum);
          _textCtrl.text = normalizedNum;
          _onSubmit(normalizedNum);
          hasInitialQuery = true;
          // 검색어가 제공된 경우 포커스 해제
          _focusNode.unfocus();
        }
      } else if (args is String) {
        final normalizedNum = normalizePhone(args);
        _textCtrl.text = normalizedNum;
        _onSubmit(normalizedNum);
        hasInitialQuery = true;
        // 검색어가 제공된 경우 포커스 해제
        _focusNode.unfocus();
      }

      // 검색어가 없는 경우에만 포커스 요청
      if (!hasInitialQuery) {
        _focusNode.requestFocus();
      }
    });
  }

  void _onSubmit(String num) async {
    final normalizedNum = normalizePhone(num.trim());
    if (normalizedNum.isEmpty) return;

    // 검색 시작 시 키보드 포커스 해제
    _focusNode.unfocus();

    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
      _result = null;
    });

    try {
      // 컨트롤러 인스턴스 메서드 호출로 변경
      final phoneData = await _searchController.searchPhone(
        normalizedNum,
        isRequested: widget.isRequested,
      );

      if (!mounted) return;
      setState(() {
        _result = SearchResultModel(
          phoneNumberModel: phoneData,
          todayRecords: phoneData?.todayRecords ?? [],
        );
      });
    } catch (e) {
      String errorMessage = e.toString().replaceAll('Exception: ', '');
      log('[SearchScreen] Caught Exception: $errorMessage');
      if (mounted) setState(() => _error = errorMessage);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _textCtrl.dispose();
    // SearchRecordsController가 로컬에서 생성된 경우 추가 정리 코드 실행 가능
    // 현재는 별도 처리 없이 그냥 해제
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
          focusNode: _focusNode,
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.red,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      );
    }
    if (_result == null) {
      return const Center(
        child: Text('검색어를 입력해주세요.', style: TextStyle(color: Colors.grey)),
      );
    }

    return SearchResultWidget(searchResult: _result!);
  }
}
