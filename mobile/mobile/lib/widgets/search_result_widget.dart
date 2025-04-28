import 'package:flutter/material.dart';
import 'package:mobile/models/search_result_model.dart';
import 'package:mobile/models/phone_number_model.dart';
import 'package:mobile/models/today_record.dart';
import 'package:mobile/utils/constants.dart';
import 'dart:developer'; // <<< 로그 사용 위해 추가

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

    // <<< isRegisteredUser 플래그 확인 >>>
    final bool isUser = phoneNumberModel?.isRegisteredUser ?? false;
    final userInfo = phoneNumberModel?.registeredUserInfo;

    // <<< 로그 출력 (유지) >>>
    log('[SearchResultWidget] Building with data:');
    log('[SearchResultWidget]   - isRegisteredUser: $isUser');
    log('[SearchResultWidget]   - registeredUserInfo: ${userInfo?.toJson()}');

    // <<< 최상위 분기: 사용자인 경우와 아닌 경우 >>>
    if (isUser && userInfo != null) {
      // --- 등록된 사용자인 경우 ---
      return _buildRegisteredUserInfo(userInfo);
    } else {
      // --- 등록되지 않았거나 정보가 없는 경우 (기존 로직) ---
      final todayRecords = phoneNumberModel?.todayRecords ?? [];
      final phoneRecords = phoneNumberModel?.records ?? [];

      if (phoneNumberModel == null) {
        // 검색 결과 자체가 없는 경우
        return Column(
          children: [
            _buildHeader(null, null, false), // 헤더는 신규 번호 메시지 표시
            const Expanded(
              child: Center(
                child: Text(
                  '등록된 정보가 없습니다.',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ),
          ],
        );
      }

      // 기존 UI 구조 (Header + Divider + ListView)
      return Column(
        children: [
          _buildHeader(phoneNumberModel, null, false),
          const Divider(
            color: Colors.grey,
            thickness: 0.3,
            indent: 16.0,
            endIndent: 16.0,
            height: 0,
          ),
          Expanded(
            child:
                widget.ignorePointer
                    ? IgnorePointer(
                      child: _buildRecordListView(todayRecords, phoneRecords),
                    )
                    : _buildRecordListView(todayRecords, phoneRecords),
          ),
        ],
      );
    }
  }

  // <<< 헤더 빌드 로직 (수정 없음) >>>
  Widget _buildHeader(
    PhoneNumberModel? phoneNumberModel,
    RegisteredUserInfoModel? userInfo,
    bool isUser,
  ) {
    final typeColor = _pickColorForType(phoneNumberModel?.type ?? 0);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.grey.shade100,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (isUser && userInfo != null) ...[
            CircleAvatar(
              backgroundColor: _pickColorForUserType(userInfo.userType),
              radius: 16,
              child: Text(
                userInfo.userType.length > 2
                    ? userInfo.userType.substring(0, 2)
                    : userInfo.userType,
                style: const TextStyle(color: Colors.white, fontSize: 10),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                phoneNumberModel!.phoneNumber,
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ] else if (phoneNumberModel != null) ...[
            CircleAvatar(
              backgroundColor: typeColor,
              radius: 16,
              child: Text(
                '${phoneNumberModel.type}',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                phoneNumberModel.phoneNumber,
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ] else ...[
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
    );
  }

  // <<< 리스트 뷰 빌드 로직 (수정 없음) >>>
  Widget _buildRecordListView(
    List<TodayRecord> todayRecords,
    List<PhoneRecordModel> phoneRecords,
  ) {
    return ListView.separated(
      controller: widget.scrollController,
      shrinkWrap: true,
      physics: const ClampingScrollPhysics(),
      primary: false,
      padding: EdgeInsets.zero,
      itemCount: _calculateItemCount(todayRecords, phoneRecords),
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
        return _buildItem(context, index, todayRecords, phoneRecords);
      },
    );
  }

  // <<< 등록된 사용자 정보 표시 위젯 수정 >>>
  Widget _buildRegisteredUserInfo(RegisteredUserInfoModel userInfo) {
    final userTypeColor = _pickColorForUserType(userInfo.userType);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 10),
            // 1. "KOLPON 유저 입니다." 텍스트
            const Text(
              'KOLPON 유저 입니다.',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 24),

            // 2. 유저타입 | 유저이름 | 지역 Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // 좌측: 유저 타입
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: userTypeColor,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Text(
                    userInfo.userType,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                // 중앙: 유저 이름
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Text(
                      userInfo.userName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                    ),
                  ),
                ),

                // 우측: 지역
                if (userInfo.userRegion != null &&
                    userInfo.userRegion!.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Text(
                      userInfo.userRegion!,
                      style: TextStyle(
                        color: Colors.grey.shade800,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                else
                  const SizedBox.shrink(),
              ],
            ),

            const Spacer(),
          ],
        ),
      ),
    );
  }

  // <<< 아이템 개수 계산 메서드 (파라미터 받도록 수정) >>>
  int _calculateItemCount(
    List<TodayRecord> todayRecords,
    List<PhoneRecordModel> phoneRecords,
  ) {
    // final todayRecords = widget.searchResult?.todayRecords ?? []; // 파라미터 사용
    // final phoneRecords = widget.searchResult?.phoneNumberModel?.records ?? []; // 파라미터 사용

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

  // <<< itemBuilder 수정 (파라미터 받도록) >>>
  Widget _buildItem(
    BuildContext context,
    int index,
    List<TodayRecord> todayRecords,
    List<PhoneRecordModel> phoneRecords,
  ) {
    // final todayRecords = widget.searchResult?.todayRecords ?? []; // 파라미터 사용
    // final phoneRecords = widget.searchResult?.phoneNumberModel?.records ?? []; // 파라미터 사용

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
    final phoneSectionStart = _calculatePhoneSectionStart(todayRecords);
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

    // <<< 모든 조건에 해당하지 않을 경우 빈 위젯 반환 >>>
    return const SizedBox.shrink();
  }

  // <<< PhoneRecord 섹션 시작 인덱스 계산 (파라미터 받도록) >>>
  int _calculatePhoneSectionStart(List<TodayRecord> todayRecords) {
    // final todayRecords = widget.searchResult?.todayRecords ?? []; // 파라미터 사용
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
