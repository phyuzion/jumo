import 'package:flutter/material.dart';
import 'package:mobile/models/search_result_model.dart';
import 'package:mobile/models/phone_number_model.dart';
import 'package:mobile/models/today_record.dart';
import 'package:mobile/utils/constants.dart';

class SearchResultWidget extends StatelessWidget {
  final SearchResultModel searchResult;
  const SearchResultWidget({super.key, required this.searchResult});

  @override
  Widget build(BuildContext context) {
    if (searchResult.isNew) {
      return const Center(
        child: Text('신규 번호입니다.', style: TextStyle(color: Colors.grey)),
      );
    }

    // 타입 컬러
    final typeColor = _pickColorForType(
      searchResult.phoneNumberModel?.type ?? 0,
    );

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
                radius: 20,
                child: Text(
                  '${searchResult.phoneNumberModel?.type ?? 0}',
                  style: const TextStyle(color: Colors.white, fontSize: 18),
                ),
              ),
              const SizedBox(width: 20),
              // 전화번호 (굵게)
              Expanded(
                child: Text(
                  searchResult.phoneNumberModel?.phoneNumber ?? '',
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
        Expanded(child: _buildRecordsList()),
      ],
    );
  }

  Widget _buildRecordsList() {
    final phoneRecords = searchResult.phoneNumberModel?.records ?? [];
    final todayRecords = searchResult.todayRecords ?? [];

    if (phoneRecords.isEmpty && todayRecords.isEmpty) {
      return const Center(
        child: Text('레코드가 없습니다.', style: TextStyle(color: Colors.grey)),
      );
    }

    return ListView.separated(
      itemCount:
          (todayRecords.isNotEmpty ? 1 : 0) + // TodayRecord 섹션
          todayRecords.length + // TodayRecord 아이템들
          (todayRecords.length > 3 ? 1 : 0) + // 더보기 버튼
          (phoneRecords.isNotEmpty ? 1 : 0) + // PhoneRecord 섹션
          phoneRecords.length + // PhoneRecord 아이템들
          (phoneRecords.isNotEmpty ? 1 : 0), // 마지막 아이템을 위한 추가 공간
      separatorBuilder: (context, index) {
        return const Divider(
          color: Colors.grey,
          thickness: 0.5,
          indent: 16.0,
          endIndent: 16.0,
          height: 0,
        );
      },
      itemBuilder: (context, index) {
        // TodayRecord 섹션 헤더
        if (index == 0 && todayRecords.isNotEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              '최근 통화',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          );
        }

        // TodayRecord 아이템들
        if (index > 0 && index <= todayRecords.length) {
          return _buildTodayRecordItem(todayRecords[index - 1]);
        }

        // 더보기 버튼
        if (index == todayRecords.length + 1 && todayRecords.length > 3) {
          return TextButton(
            onPressed: () {
              // TODO: 더보기 기능 구현
            },
            child: const Text('더보기'),
          );
        }

        // PhoneRecord 섹션 헤더
        if (index == todayRecords.length + (todayRecords.length > 3 ? 2 : 1) &&
            phoneRecords.isNotEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              '검색 결과',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          );
        }

        // PhoneRecord 아이템들
        final headerOffset =
            todayRecords.length + (todayRecords.length > 3 ? 2 : 1);
        final phoneRecordIndex =
            index - headerOffset - (phoneRecords.isNotEmpty ? 1 : 0);

        // 음수 인덱스 체크
        if (phoneRecordIndex < 0 || phoneRecordIndex >= phoneRecords.length) {
          return const SizedBox.shrink();
        }

        return _buildPhoneRecordItem(phoneRecords[phoneRecordIndex]);
      },
    );
  }

  Widget _buildPhoneRecordItem(PhoneRecordModel r) {
    final userTypeColor = _pickColorForUserType(r.userType);
    final recordTypeColor = (r.type == 99) ? Colors.red : Colors.blueGrey;
    final epoch = int.tryParse(r.createdAt);
    DateTime? dt;
    if (epoch != null) {
      dt = DateTime.fromMillisecondsSinceEpoch(epoch);
    }
    final yearStr = (dt != null) ? '${dt.year}' : '';
    final dateStr = formatDateOnly(r.createdAt);
    final timeStr = formatTimeOnly(r.createdAt);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 왼쪽 userType 서클
            CircleAvatar(
              backgroundColor: userTypeColor,
              radius: 16,
              child: Text(
                r.userType.length > 2 ? r.userType.substring(0, 2) : r.userType,
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
            const SizedBox(width: 12),

            // 가운데(이름, userName, 메모)
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
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
                      style: const TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                  if (r.memo.isNotEmpty)
                    Text(
                      r.memo,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14),
                    ),
                ],
              ),
            ),

            const SizedBox(width: 12),

            // 오른쪽: type 서클 + 시간
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CircleAvatar(
                  backgroundColor: recordTypeColor,
                  radius: 16,
                  child: Text(
                    '${r.type}',
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ),
                const SizedBox(width: 8),
                // 시간
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      yearStr,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
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
      ),
    );
  }

  Widget _buildTodayRecordItem(TodayRecord r) {
    final epoch = int.tryParse(r.createdAt);
    DateTime? dt;
    if (epoch != null) {
      dt = DateTime.fromMillisecondsSinceEpoch(epoch);
    }
    final yearStr = (dt != null) ? '${dt.year}' : '';
    final dateStr = formatDateOnly(r.createdAt);
    final timeStr = formatTimeOnly(r.createdAt);

    // userType 컬러
    final userTypeColor = _pickColorForUserType(r.userType);

    // callType에 따른 아이콘 설정
    IconData iconData;
    Color iconColor;
    switch (r.callType.toLowerCase()) {
      case 'in':
        iconData = Icons.call_received;
        iconColor = Colors.green;
        break;
      case 'out':
        iconData = Icons.call_made;
        iconColor = Colors.blue;
        break;
      case 'miss':
        iconData = Icons.call_missed;
        iconColor = Colors.red;
        break;
      default:
        iconData = Icons.phone;
        iconColor = Colors.grey;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(iconData, color: iconColor, size: 30),

          // 왼쪽: userType 서클
          const SizedBox(width: 12),

          // 가운데: 아이콘 + 이름
          Expanded(
            child: Row(
              children: [
                const SizedBox(width: 8),
                Text(
                  r.userName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: userTypeColor,
                radius: 16,
                child: Text(
                  r.userType,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    yearStr,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
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
          // 오른쪽: 날짜/시간
        ],
      ),
    );
  }

  // 메인 typeColor
  Color _pickColorForType(int type) {
    return (type == 99) ? Colors.red : Colors.blueGrey;
  }

  // userType별 컬러
  Color _pickColorForUserType(String userType) {
    // userType 문자열의 해시값을 기반으로 색상 생성
    final colors = [
      Colors.red,
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.indigo,
      Colors.pink,
      Colors.amber,
      Colors.cyan,
    ];

    final hash = userType.hashCode.abs();
    return colors[hash % colors.length];
  }
}
