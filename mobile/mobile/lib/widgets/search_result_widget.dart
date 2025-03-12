// lib/widgets/search_result_widget.dart

import 'package:flutter/material.dart';
import 'package:mobile/graphql/search_api.dart';
import 'package:mobile/models/phone_number_model.dart';
import 'package:mobile/utils/constants.dart'; // normalizePhone (optional)

/// 간단히 "전화번호" 하나만 주면, 내부적으로 fetch 후
/// 결과 UI(에러/로딩/결과없음/결과리스트) 를 보여주는 재사용 위젯
class SearchResultWidget extends StatefulWidget {
  final String phoneNumber;
  const SearchResultWidget({Key? key, required this.phoneNumber})
    : super(key: key);

  @override
  State<SearchResultWidget> createState() => _SearchResultWidgetState();
}

class _SearchResultWidgetState extends State<SearchResultWidget> {
  bool _loading = false;
  String? _error;
  PhoneNumberModel? _result;

  @override
  void initState() {
    super.initState();
    _fetchResult();
  }

  Future<void> _fetchResult() async {
    setState(() {
      _loading = true;
      _error = null;
      _result = null;
    });

    try {
      // 전화번호 정규화
      final normalized = normalizePhone(widget.phoneNumber);
      final data = await SearchApi.getPhoneNumber(normalized);
      setState(() => _result = data); // null 이면 결과없음
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 상단 요약(번호, type 등)
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '번호: ${model.phoneNumber}',
                style: const TextStyle(fontSize: 18),
              ),
              SizedBox(width: 30),
              Text('type: ${model.type}', style: const TextStyle(fontSize: 16)),
            ],
          ),
        ),
        const Divider(height: 1),

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
    // createdAt 이 epoch 라 가정
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
          // 왼쪽 userType 동그라미
          CircleAvatar(
            backgroundColor: userTypeColor,
            radius: 20,
            child: Text(
              '${r.userType}',
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
          const SizedBox(width: 12),

          // 가운데 2개 칼럼
          Expanded(
            child: Row(
              children: [
                // name / userName
                Expanded(
                  flex: 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r.name.isNotEmpty ? r.name : '(이름 없음)',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
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
                // memo
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

          // 오른쪽: type 동그라미 + 날짜/시간
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: typeColor,
                radius: 20,
                child: Text(
                  '${r.type}',
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    dateStr,
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                  ),
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
