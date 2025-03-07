import 'package:flutter/material.dart';
import '../controllers/call_log_controller.dart';

class RecentCallsScreen extends StatefulWidget {
  const RecentCallsScreen({Key? key}) : super(key: key);

  @override
  State<RecentCallsScreen> createState() => _RecentCallsScreenState();
}

class _RecentCallsScreenState extends State<RecentCallsScreen> {
  final _callLogController = CallLogController();
  List<Map<String, dynamic>> _callLogs = [];

  @override
  void initState() {
    super.initState();
    _loadCalls();
  }

  /// 이미 저장된 통화로그(최대 200개) 불러오기
  Future<void> _loadCalls() async {
    final logs = _callLogController.getSavedCallLogs();
    setState(() => _callLogs = logs);
  }

  /// 새로고침해서 callLogController.refreshCallLogsWithDiff() 실행 → 저장된 목록 갱신
  Future<void> _refreshCalls() async {
    // 새 통화 내역 가져와 diff 반영
    await _callLogController.refreshCallLogsWithDiff();
    // 다시 로드
    await _loadCalls();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('최근기록')),
      // Pull to Refresh 가능: 새로고침 시 _refreshCalls()
      body: RefreshIndicator(
        onRefresh: _refreshCalls,
        child: ListView.builder(
          itemCount: _callLogs.length,
          itemBuilder: (context, index) {
            final call = _callLogs[index];
            final number = call['number'] as String? ?? '';
            final name = call['name'] as String? ?? '';
            final callType = call['callType'] as String? ?? '';
            final ts = call['timestamp'] as int? ?? 0;

            // timestamp → DateTime
            final date = DateTime.fromMillisecondsSinceEpoch(ts);
            // 간단 포맷 (시간만 예시)
            final timeStr =
                '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

            // callType 에 따라 아이콘/색상 지정
            IconData iconData;
            Color iconColor;
            switch (callType) {
              case 'incoming':
                iconData = Icons.call_received;
                iconColor = Colors.green;
                break;
              case 'outgoing':
                iconData = Icons.call_made;
                iconColor = Colors.blue;
                break;
              case 'missed':
                iconData = Icons.call_missed;
                iconColor = Colors.red;
                break;
              default:
                iconData = Icons.phone; // unknown
                iconColor = Colors.grey;
            }

            return ListTile(
              leading: Icon(iconData, color: iconColor),
              title: Text(
                name.isNotEmpty ? name : number,
                style: const TextStyle(fontSize: 16),
              ),
              // timeStr or date...
              trailing: Text(
                timeStr,
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
            );
          },
        ),
      ),
    );
  }
}
