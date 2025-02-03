import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fluttertoast/fluttertoast.dart';
// import 'package:call_log/call_log.dart';  // 실제 통화 기록을 가져올 때 사용

class RecentCallTab extends StatefulWidget {
  const RecentCallTab({Key? key}) : super(key: key);

  @override
  _RecentCallTabState createState() => _RecentCallTabState();
}

class _RecentCallTabState extends State<RecentCallTab> {
  // 실제 환경에서는 CallLog.get() 등을 통해 최근 24시간의 기록을 가져옵니다.
  // 여기서는 예시 데이터를 사용합니다.
  final List<Map<String, String>> recentCalls = [
    {"phone": "010-1234-5678", "dateTime": "25/02/03 22:30"},
    {"phone": "010-9876-5432", "dateTime": "25/02/03 21:15"},
  ];

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: recentCalls.length,
      separatorBuilder: (context, index) => const Divider(),
      itemBuilder: (context, index) {
        final record = recentCalls[index];
        return ListTile(
          leading: Text(record["phone"]!, style: const TextStyle(fontSize: 16)),
          title: Text(
            record["dateTime"]!,
            style: const TextStyle(fontSize: 16),
          ),
          trailing: ElevatedButton(
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(0), // 네모 스타일
              ),
            ),
            onPressed: () {
              Fluttertoast.showToast(msg: "저장 기능은 준비 중입니다.");
            },
            child: const Text("저장"),
          ),
        );
      },
    );
  }
}
