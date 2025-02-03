import 'package:flutter/material.dart';
import 'edit_call_dialog.dart';
import 'package:fluttertoast/fluttertoast.dart';

class MyRecordTab extends StatefulWidget {
  const MyRecordTab({Key? key}) : super(key: key);

  @override
  _MyRecordTabState createState() => _MyRecordTabState();
}

class _MyRecordTabState extends State<MyRecordTab> {
  // 실제 데이터는 GraphQL API를 통해 받아오지만, 여기서는 예시 데이터를 사용합니다.
  List<Map<String, dynamic>> myCallLogs = [
    {
      "phone": "010-1111-2222",
      "dateTime": "25/02/03 20:45",
      "memo": "통화 내용 메모 예시입니다. 아주 긴 메모도 가능합니다.",
      "rating": 4.5,
    },
    {
      "phone": "010-3333-4444",
      "dateTime": "25/02/03 19:30",
      "memo": "다른 통화 기록 메모입니다.",
      "rating": 3.0,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: myCallLogs.length,
      separatorBuilder: (context, index) => const Divider(height: 20),
      itemBuilder: (context, index) {
        final log = myCallLogs[index];
        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(0), // 네모 스타일
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 왼쪽 영역: 기록 내용 (전화번호, 날짜 / 메모, 별점)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 첫 번째 행: 전화번호와 날짜 (양쪽 정렬)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          log["phone"],
                          style: const TextStyle(fontSize: 16),
                        ),
                        Text(
                          log["dateTime"],
                          style: const TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // 두 번째 행: 메모와 별점
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(0),
                            ),
                            child: Text(
                              log["memo"],
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 1,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(0),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.star,
                                  color: Colors.amber,
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  log["rating"].toString(),
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // 오른쪽 영역: 수정 버튼 (전체 2줄 높이를 차지)
              Container(
                margin: const EdgeInsets.only(left: 8),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(80, 80),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(0), // 네모 스타일
                    ),
                  ),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => EditCallDialog(callLog: log),
                    );
                  },
                  child: const Text("수정", textAlign: TextAlign.center),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
