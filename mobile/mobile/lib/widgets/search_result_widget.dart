import 'package:flutter/material.dart';
import 'package:mobile/models/phone_number_model.dart';

class SearchResultWidget extends StatelessWidget {
  final PhoneNumberModel phoneNumberModel;
  const SearchResultWidget({Key? key, required this.phoneNumberModel})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 레코드 리스트
    final records = phoneNumberModel.records;

    // 타입 컬러
    final typeColor = _pickColorForType(phoneNumberModel.type);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // -----------------------------
        // (1) 상단 헤더부: phoneNumber + type
        // -----------------------------
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.grey.shade200,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Type 서클
              CircleAvatar(
                backgroundColor: typeColor,
                radius: 20, // 스타일 통일
                child: Text(
                  '${phoneNumberModel.type}',
                  style: const TextStyle(color: Colors.white, fontSize: 18),
                ),
              ),
              const SizedBox(width: 20),
              // 전화번호 (굵게)
              Expanded(
                child: Text(
                  phoneNumberModel.phoneNumber,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),

        // -----------------------------
        // (2) 레코드 목록
        // -----------------------------
        // 높이 확장을 위해 Expanded
        // 이 위젯이 들어가는 곳(부모)이 Column이면 Expanded가 잘 동작
        Expanded(
          child:
              records.isEmpty
                  ? const Center(
                    child: Text(
                      '레코드가 없습니다.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                  : ListView.separated(
                    itemCount: records.length,
                    separatorBuilder:
                        (context, index) => const Divider(
                          color: Colors.grey,
                          thickness: 0.5,
                          indent: 16.0,
                          endIndent: 16.0,
                          height: 0,
                        ),
                    itemBuilder: (context, index) {
                      final r = records[index];
                      return _buildRecordItem(r);
                    },
                  ),
        ),
      ],
    );
  }

  /// 레코드 하나의 Row
  Widget _buildRecordItem(PhoneRecordModel r) {
    // createdAt이 epoch라 가정
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

    // userType / record type 컬러
    final userTypeColor = _pickColorForUserType(r.userType);
    final recordTypeColor = (r.type == 99) ? Colors.red : Colors.blueGrey;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 왼쪽 userType 서클
          CircleAvatar(
            backgroundColor: userTypeColor,
            radius: 16, // 스타일 통일
            child: Text(
              '${r.userType}',
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
          const SizedBox(width: 12),

          // 가운데(이름, userName, 메모)
          Expanded(
            child: Row(
              children: [
                // (이름, userName)
                Expanded(
                  flex: 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r.name.isNotEmpty ? r.name : '(이름 없음)',
                        style: const TextStyle(
                          fontSize: 15,
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
                // 메모
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

          // 오른쪽: record type 서클 + 날짜/시간
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: recordTypeColor,
                radius: 16, // 동일 스타일
                child: Text(
                  '${r.type}',
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    dateStr,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  Text(
                    timeStr,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 메인 typeColor
  Color _pickColorForType(int type) {
    return (type == 99) ? Colors.red : Colors.blueGrey;
  }

  // userType별 컬러
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
