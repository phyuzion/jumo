// lib/widgets/search_result_widget.dart

import 'package:flutter/material.dart';
import 'package:mobile/models/phone_number_model.dart';

class SearchResultWidget extends StatelessWidget {
  final PhoneNumberModel phoneNumberModel;
  const SearchResultWidget({Key? key, required this.phoneNumberModel})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
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
                '번호: ${phoneNumberModel.phoneNumber}',
                style: const TextStyle(fontSize: 18),
              ),
              SizedBox(width: 30),
              Text(
                'type: ${phoneNumberModel.type}',
                style: const TextStyle(fontSize: 16),
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        Expanded(
          child:
              phoneNumberModel.records.isEmpty
                  ? const Center(
                    child: Text(
                      '레코드가 없습니다.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                  : ListView.builder(
                    itemCount: phoneNumberModel.records.length,
                    itemBuilder: (context, index) {
                      final r = phoneNumberModel.records[index];
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
