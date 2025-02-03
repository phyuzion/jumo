import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:intl/intl.dart';
import 'edit_call_dialog.dart';
import '../graphql/queries.dart';
import '../util/constants.dart';

class MyRecordTab extends StatefulWidget {
  const MyRecordTab({Key? key}) : super(key: key);

  @override
  State<MyRecordTab> createState() => _MyRecordTabState();
}

class _MyRecordTabState extends State<MyRecordTab> {
  final box = GetStorage();
  final ScrollController _scrollController = ScrollController();
  List<dynamic> _callLogs = [];
  bool _isFetchingMore = false;
  int _currentStart = 1;
  final int _pageSize = 20;
  bool _hasMore = true;

  String _userId = "";
  String _phone = "";

  // GraphQL client (GraphQLProvider는 main.dart에서 설정됨)
  late GraphQLClient _client;

  @override
  void initState() {
    super.initState();
    _loadUserCredentials();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _client = GraphQLProvider.of(context).value;
      _fetchRecords(reset: true);
    });
    _scrollController.addListener(_onScroll);
  }

  void _loadUserCredentials() {
    _userId = box.read(USER_ID_KEY) ?? "";
    _phone = box.read(USER_PHONE_KEY) ?? "";
  }

  Future<void> _fetchRecords({bool reset = false}) async {
    if (reset) {
      _currentStart = 1;
      _hasMore = true;
      _callLogs.clear();
      setState(() {});
    }
    if (!_hasMore) return;
    final int end = _currentStart + _pageSize - 1;
    final QueryOptions options = QueryOptions(
      document: gql(GET_CALL_LOGS_FOR_USER),
      variables: {
        'userId': _userId,
        'phone': _phone,
        'start': _currentStart,
        'end': end,
      },
      fetchPolicy: FetchPolicy.networkOnly,
    );
    final result = await _client.query(options);
    if (result.hasException) {
      // 에러 처리 (예: 토스트)
      return;
    }
    final List<dynamic> fetched = result.data?['getCallLogsForUser'] ?? [];
    setState(() {
      _callLogs.addAll(fetched);
      _currentStart += _pageSize;
      if (fetched.length < _pageSize) {
        _hasMore = false;
      }
    });
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isFetchingMore &&
        _hasMore) {
      _isFetchingMore = true;
      _fetchRecords().then((_) {
        _isFetchingMore = false;
      });
    }
  }

  // 포맷팅 함수: timestamp를 "dd/MM/yy HH:mm" (예: "25/02/03 22:30")로 변환
  String _formatDateTime(dynamic timestamp) {
    // timestamp가 밀리초 정수 또는 문자열 형태라고 가정
    int ms;
    if (timestamp is int) {
      ms = timestamp;
    } else {
      ms = int.tryParse(timestamp.toString()) ?? 0;
    }
    DateTime dt = DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
    // 원하면 로컬 타임존으로 변환하거나, 그대로 UTC+9 등을 적용할 수 있음.
    // 여기서는 단순히 DateFormat 사용 (필요에 따라 수정)
    return DateFormat('dd/MM/yy HH:mm').format(dt);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // UI: 각 콜로그 항목을 두 줄로 표시
  Widget _buildCallLogItem(Map<String, dynamic> log) {
    final String phone = log["customerId"]?["phone"] ?? "Unknown";
    final String dateTime =
        log["timestamp"] != null ? _formatDateTime(log["timestamp"]) : "";
    final String memo = log["memo"] ?? "";
    final String rating =
        log["score"] != null
            ? log["score"].toString()
            : "0"; // 여기서 별점은 score로 처리 (필요 시 별도의 rating 필드를 사용)

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(0),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 왼쪽: 기록 내용
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 첫 번째 행: 전화번호와 날짜 (양쪽 정렬)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [Text(phone, style: const TextStyle(fontSize: 16))],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(dateTime, style: const TextStyle(fontSize: 16)),
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
                        child: Text(memo, style: const TextStyle(fontSize: 14)),
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
                            Text(rating, style: const TextStyle(fontSize: 14)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // 오른쪽: 수정 버튼 (수정 다이얼로그 호출)
          Container(
            margin: const EdgeInsets.only(left: 8),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(80, 80), // 2줄 높이
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(0),
                ),
              ),
              onPressed: () {
                // 수정 버튼 누르면 수정 다이얼로그(EditCallDialog) 호출
                showDialog(
                  context: context,
                  builder:
                      (context) => EditCallDialog(callLog: log, isNew: false),
                );
              },
              child: const Text("수정", textAlign: TextAlign.center),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        await _fetchRecords(reset: true);
      },
      child: ListView.separated(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: _callLogs.length,
        separatorBuilder: (context, index) => const Divider(height: 20),
        itemBuilder: (context, index) {
          final log = _callLogs[index] as Map<String, dynamic>;
          return _buildCallLogItem(log);
        },
      ),
    );
  }
}
