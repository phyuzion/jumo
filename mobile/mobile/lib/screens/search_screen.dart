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

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map<String, dynamic>) {
        final initialNum = args['number'] as String?;
        if (initialNum != null) {
          final normalizedNum = normalizePhone(initialNum);
          _textCtrl.text = normalizedNum;
          _onSubmit(normalizedNum);
        }
      } else if (args is String) {
        final normalizedNum = normalizePhone(args);
        _textCtrl.text = normalizedNum;
        _onSubmit(normalizedNum);
      }
      _focusNode.requestFocus();
    });
  }

  void _onSubmit(String num) async {
    final normalizedNum = normalizePhone(num.trim());
    if (normalizedNum.isEmpty) return;

    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
      _result = null;
    });

    try {
      final phoneData = await SearchRecordsController.searchPhone(
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
