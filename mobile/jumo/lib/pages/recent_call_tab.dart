import 'package:flutter/material.dart';
import 'package:call_e_log/call_log.dart';
import 'package:intl/intl.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'edit_call_dialog.dart';

class RecentCallTab extends StatefulWidget {
  const RecentCallTab({Key? key}) : super(key: key);

  @override
  _RecentCallTabState createState() => _RecentCallTabState();
}

class _RecentCallTabState extends State<RecentCallTab> {
  List<CallLogEntry> _entries = [];

  @override
  void initState() {
    super.initState();
    _fetchRecentCallLogs();
  }

  Future<void> _fetchRecentCallLogs() async {
    try {
      // call_log 패키지를 사용하여 전체 통화 기록을 가져옵니다.
      Iterable<CallLogEntry> entries = await CallLog.get();
      // 최근 3일 전의 밀리초 타임스탬프 계산
      final threeDaysAgo =
          DateTime.now()
              .subtract(const Duration(days: 3))
              .millisecondsSinceEpoch;
      // 수신 통화만 필터링하고, 최근 3일 내의 기록만 선택
      List<CallLogEntry> filtered =
          entries
              .where(
                (entry) =>
                    entry.callType == CallType.incoming &&
                    entry.timestamp != null &&
                    entry.timestamp! >= threeDaysAgo,
              )
              .toList();
      // 최신순 정렬
      filtered.sort((a, b) => b.timestamp!.compareTo(a.timestamp!));
      // 최대 50건만 사용
      if (filtered.length > 50) {
        filtered = filtered.sublist(0, 50);
      }
      setState(() {
        _entries = filtered;
      });
    } catch (e) {
      Fluttertoast.showToast(msg: '통화 기록을 가져오는 중 오류 발생: $e');
    }
  }

  String _formatDateTime(int timestamp) {
    DateTime dt = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final formatter = DateFormat('dd/MM/yy HH:mm');
    return formatter.format(dt);
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _fetchRecentCallLogs,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _entries.length,
        separatorBuilder: (context, index) => const Divider(),
        itemBuilder: (context, index) {
          final entry = _entries[index];
          final phone = entry.number ?? 'Unknown';
          final dateTime =
              entry.timestamp != null ? _formatDateTime(entry.timestamp!) : '';
          return ListTile(
            title: Text(phone, style: const TextStyle(fontSize: 16)),
            subtitle: Text(dateTime, style: const TextStyle(fontSize: 16)),
            trailing: ElevatedButton(
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(0), // 네모 스타일
                ),
              ),
              onPressed: () {
                // "저장" 버튼을 누르면, 수정 다이얼로그(EditCallDialog)를 띄웁니다.
                // 신규 저장인 경우, 초기 메모와 별점은 빈 값으로 전달합니다.
                showDialog(
                  context: context,
                  builder:
                      (context) => EditCallDialog(
                        callLog: {
                          "phone": phone,
                          "dateTime": dateTime,
                          "memo": "",
                          "rating": 5,
                        },
                        isNew: true,
                      ),
                );
              },
              child: const Text("저장"),
            ),
          );
        },
      ),
    );
  }
}
