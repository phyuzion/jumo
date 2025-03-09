import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:mobile/graphql/search_api.dart';
import 'package:mobile/models/phone_number_model.dart';
import 'package:mobile/utils/constants.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

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
        _onSubmit(_textCtrl.text); // 전달된 번호로 즉시 검색
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 상단에 검색 TextField가 있는 AppBar
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
    // 결과가 있을 때
    return _buildResultView(_result!);
  }

  Widget _buildResultView(PhoneNumberModel model) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 상단 요약(번호, 최상위 type 등)
        Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '번호: ${model.phoneNumber}',
                style: const TextStyle(fontSize: 18),
              ),
              Text('type: ${model.type}', style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 8),
              const Text(
                '등록된 레코드들:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // 레코드 리스트
        Expanded(
          child:
              model.records.isEmpty
                  ? const Center(
                    child: Text(
                      '레코드가 없습니다.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                  : ListView.builder(
                    itemCount: model.records.length,
                    itemBuilder: (context, index) {
                      final r = model.records[index];
                      return _buildRecordItem(r);
                    },
                  ),
        ),
      ],
    );
  }

  Widget _buildRecordItem(PhoneRecordModel r) {
    // createdAt이 epoch time(예: 1739146680000)이라고 가정
    final epoch = int.tryParse(r.createdAt);
    DateTime? dt;
    if (epoch != null) {
      dt = DateTime.fromMillisecondsSinceEpoch(epoch);
    }

    final dateStr = (dt != null) ? '${dt.month}/${dt.day}' : '';
    final timeStr =
        (dt != null)
            ? '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}'
            : '';

    // userType / type 색상
    final userTypeColor = _pickColorForUserType(r.userType);
    final typeColor = (r.type == 99) ? Colors.red : Colors.blueGrey;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // (1) 왼쪽: userType 동그라미
          CircleAvatar(
            backgroundColor: userTypeColor,
            radius: 20,
            child: Text(
              '${r.userType}',
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
          const SizedBox(width: 12),

          // (2) 가운데 2개 칼럼 (Left: name/userName, Right: memo)
          Expanded(
            child: Row(
              children: [
                // 왼쪽 Column
                Expanded(
                  flex: 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 큰 글씨 name
                      Text(
                        r.name.isNotEmpty ? r.name : '(이름 없음)',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      // userName
                      if (r.userName.isNotEmpty)
                        Text(
                          r.userName,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.grey,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // 오른쪽 Column (memo, 최대 2줄)
                Expanded(
                  flex: 1,
                  child:
                      (r.memo.isNotEmpty)
                          ? Text(
                            r.memo,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 14),
                          )
                          : const SizedBox(),
                ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          // (3) 오른쪽: CircleAvatar(type) + 날짜/시간(2줄)을 가로로
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // (3-1) type 동그라미
              CircleAvatar(
                backgroundColor: typeColor,
                radius: 20,
                child: Text(
                  '${r.type}',
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
              const SizedBox(width: 8),
              // (3-2) 날짜/시간(2줄)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // 날짜
                  Text(
                    dateStr,
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  // 시간
                  Text(
                    timeStr,
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// userType 값에 따른 색상 예시
  Color _pickColorForUserType(int userType) {
    switch (userType) {
      case 99:
        return Colors.red;
      case 1:
        return Colors.blue;
      case 2:
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}
