import 'package:flutter/material.dart';
import 'package:mobile/models/search_result_model.dart';
import 'package:mobile/models/phone_number_model.dart';
import 'package:mobile/models/today_record.dart';
import 'package:mobile/utils/constants.dart';

class SearchResultWidget extends StatefulWidget {
  final SearchResultModel? searchResult;
  final ScrollController? scrollController;
  final bool ignorePointer;

  const SearchResultWidget({
    super.key,
    required this.searchResult,
    this.scrollController,
    this.ignorePointer = false,
  });

  @override
  State<SearchResultWidget> createState() => _SearchResultWidgetState();
}

class _SearchResultWidgetState extends State<SearchResultWidget> {
  bool _showAllTodayRecords = false; // 더보기 상태

  @override
  Widget build(BuildContext context) {
    final phoneNumberModel = widget.searchResult?.phoneNumberModel;
    final todayRecords = widget.searchResult?.todayRecords ?? [];

    // 타입 컬러
    final typeColor = _pickColorForType(phoneNumberModel?.type ?? 0);

    return Column(
      children: [
        // -----------------------------
        // (1) 상단 헤더부: phoneNumber + type 또는 신규 번호 메시지
        // -----------------------------
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Colors.grey.shade100,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (phoneNumberModel != null) ...[
                // Type 서클
                CircleAvatar(
                  backgroundColor: typeColor,
                  radius: 16,
                  child: Text(
                    '${phoneNumberModel.type}',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
                const SizedBox(width: 12),
                // 전화번호 (굵게)
                Expanded(
                  child: Text(
                    phoneNumberModel.phoneNumber,
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ] else ...[
                // 신규 번호 메시지
                Expanded(
                  child: Center(
                    child: Text(
                      '신규 번호입니다',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        // 구분선
        const Divider(
          color: Colors.grey,
          thickness: 0.3,
          indent: 16.0,
          endIndent: 16.0,
          height: 0,
        ),
        // -----------------------------
        // (2) 하단 리스트부: todayRecords + phoneRecords
        // -----------------------------
        Expanded(
          child:
              widget.ignorePointer
                  ? IgnorePointer(
                    child: ListView.separated(
                      controller: widget.scrollController,
                      shrinkWrap: true,
                      physics: const ClampingScrollPhysics(),
                      primary: false,
                      padding: EdgeInsets.zero,
                      itemCount: _calculateItemCount(),
                      separatorBuilder: (context, index) {
                        return const Divider(
                          color: Colors.grey,
                          thickness: 0.3,
                          indent: 16.0,
                          endIndent: 16.0,
                          height: 0,
                        );
                      },
                      itemBuilder: (context, index) {
                        return _buildItem(context, index);
                      },
                    ),
                  )
                  : ListView.separated(
                    controller: widget.scrollController,
                    shrinkWrap: true,
                    physics: const ClampingScrollPhysics(),
                    primary: false,
                    padding: EdgeInsets.zero,
                    itemCount: _calculateItemCount(),
                    separatorBuilder: (context, index) {
                      return const Divider(
                        color: Colors.grey,
                        thickness: 0.3,
                        indent: 16.0,
                        endIndent: 16.0,
                        height: 0,
                      );
                    },
                    itemBuilder: (context, index) {
                      return _buildItem(context, index);
                    },
                  ),
        ),
      ],
    );
  }

  // 아이템 개수 계산 메서드
  int _calculateItemCount() {
    final todayRecords = widget.searchResult?.todayRecords ?? [];
    final phoneRecords = widget.searchResult?.phoneNumberModel?.records ?? [];

    // TodayRecord 섹션 헤더
    int count = todayRecords.isNotEmpty ? 1 : 0;

    // TodayRecord 아이템들
    if (todayRecords.isNotEmpty) {
      if (_showAllTodayRecords) {
        count += todayRecords.length;
      } else {
        count += todayRecords.length.clamp(0, 3);
      }
      // 더보기 버튼 (TodayRecord가 3개 이상일 때만)
      if (todayRecords.length > 3) {
        count += 1;
      }
    }

    // PhoneRecord 섹션 헤더
    count += phoneRecords.isNotEmpty ? 1 : 0;

    // PhoneRecord 아이템들
    count += phoneRecords.length;

    return count;
  }

  // 더보기 버튼 클릭 핸들러
  void _onMoreButtonPressed() {
    setState(() {
      _showAllTodayRecords = true;
    });
  }

  // itemBuilder 수정
  Widget _buildItem(BuildContext context, int index) {
    final todayRecords = widget.searchResult?.todayRecords ?? [];
    final phoneRecords = widget.searchResult?.phoneNumberModel?.records ?? [];

    // TodayRecord 섹션 헤더
    if (todayRecords.isNotEmpty && index == 0) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Text(
          '최근 통화',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade700,
          ),
        ),
      );
    }

    // TodayRecord 아이템들
    if (todayRecords.isNotEmpty && index > 0) {
      final recordIndex = index - 1;

      // 더보기 버튼 (TodayRecord가 3개 이상이고, 3번째 아이템 다음에만 표시)
      if (!_showAllTodayRecords &&
          recordIndex == 3 &&
          todayRecords.length > 3) {
        return TextButton(
          onPressed: _onMoreButtonPressed,
          child: const Text('더보기'),
        );
      }

      // TodayRecord 아이템 표시
      if (recordIndex < todayRecords.length &&
          (_showAllTodayRecords || recordIndex < 3)) {
        return _buildTodayRecordItem(todayRecords[recordIndex]);
      }
    }

    // PhoneRecord 섹션 헤더
    final phoneSectionStart = _calculatePhoneSectionStart();
    if (index == phoneSectionStart) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Text(
          '검색 결과',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade700,
          ),
        ),
      );
    }

    // PhoneRecord 아이템들
    final phoneRecordIndex = index - phoneSectionStart - 1;
    if (phoneRecordIndex >= 0 && phoneRecordIndex < phoneRecords.length) {
      return _buildPhoneRecordItem(phoneRecords[phoneRecordIndex]);
    }

    return const SizedBox.shrink();
  }

  // PhoneRecord 섹션 시작 인덱스 계산
  int _calculatePhoneSectionStart() {
    final todayRecords = widget.searchResult?.todayRecords ?? [];
    if (todayRecords.isEmpty) return 0;

    int count = 1; // 섹션 헤더
    if (_showAllTodayRecords) {
      count += todayRecords.length;
    } else {
      count += todayRecords.length.clamp(0, 3);
    }
    if (todayRecords.length > 3) {
      count += 1; // 더보기 버튼
    }
    return count;
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleAvatar(
            backgroundColor: userTypeColor,
            radius: 12,
            child: Text(
              r.userType.length > 2 ? r.userType.substring(0, 2) : r.userType,
              style: const TextStyle(color: Colors.white, fontSize: 10),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  r.name.isNotEmpty ? r.name : '(이름 없음)',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (r.userName.isNotEmpty) ...[
                  SizedBox(height: 0),
                  Text(
                    r.userName,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
                if (r.memo.isNotEmpty) ...[
                  SizedBox(height: 1),
                  Text(
                    r.memo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                backgroundColor: recordTypeColor,
                radius: 12,
                child: Text(
                  '${r.type}',
                  style: const TextStyle(color: Colors.white, fontSize: 10),
                ),
              ),
              const SizedBox(width: 4),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    yearStr,
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  Text(
                    dateStr,
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  Text(
                    timeStr,
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ],
          ),
        ],
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
    final userTypeColor = _pickColorForUserType(r.userType);

    // <<< interactionType에 따른 아이콘 및 색상 설정 >>>
    IconData iconData;
    Color iconColor;
    if (r.interactionType == 'SMS') {
      iconData = Icons.message; // 문자 아이콘
      iconColor = Colors.blue; // 예: 파란색
    } else {
      // 'CALL' 또는 'UNKNOWN' 등 기본값
      iconData = Icons.phone; // 전화 아이콘 (기존 callType 구분 로직 제거)
      iconColor = Colors.green; // 예: 초록색
      // 필요 시 기존 callType 로직을 여기에 추가할 수도 있지만, 모델에서 제거했으므로 불필요
      /*
      switch (r.callType.toLowerCase()) { // callType 필드 이제 없음!
        case 'in': iconData = Icons.call_received; iconColor = Colors.green; break;
        case 'out': iconData = Icons.call_made; iconColor = Colors.blue; break;
        case 'miss': iconData = Icons.call_missed; iconColor = Colors.red; break;
        default: iconData = Icons.phone; iconColor = Colors.grey;
      }
      */
    }
    // <<< 아이콘 설정 끝 >>>

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(iconData, color: iconColor, size: 22), // <<< 수정된 아이콘/색상 사용
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              r.userName,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                backgroundColor: userTypeColor,
                radius: 12,
                child: Text(
                  r.userType,
                  style: const TextStyle(color: Colors.white, fontSize: 10),
                ),
              ),
              const SizedBox(width: 4),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    yearStr,
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  Text(
                    dateStr,
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  Text(
                    timeStr,
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
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
