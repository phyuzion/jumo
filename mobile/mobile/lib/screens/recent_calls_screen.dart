import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:mobile/services/native_methods.dart';
import 'package:mobile/utils/app_event_bus.dart';
import '../controllers/call_log_controller.dart';

class RecentCallsScreen extends StatefulWidget {
  const RecentCallsScreen({super.key});

  @override
  State<RecentCallsScreen> createState() => _RecentCallsScreenState();
}

class _RecentCallsScreenState extends State<RecentCallsScreen> {
  final _callLogController = CallLogController();
  List<Map<String, dynamic>> _callLogs = [];

  StreamSubscription? _eventSub;

  @override
  void initState() {
    super.initState();
    _loadCalls();
    _eventSub = appEventBus.on<CallLogUpdatedEvent>().listen((event) {
      _loadCalls();
    });
  }

  @override
  void dispose() {
    _eventSub?.cancel();
    super.dispose();
  }

  Future<void> _loadCalls() async {
    final logs = _callLogController.getSavedCallLogs();
    setState(() => _callLogs = logs);
  }

  Future<void> _refreshCalls() async {
    await _callLogController.refreshCallLogsWithDiff();
    await _loadCalls();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 상단 AppBar 가 이미 HomeScreen(탭) 쪽에 있다면, 여기서는 body만
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

            final date = DateTime.fromMillisecondsSinceEpoch(ts);
            final timeStr =
                '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

            // callType 에 따라 아이콘/색상
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
                iconData = Icons.phone;
                iconColor = Colors.grey;
            }

            // Slidable 사용
            return Slidable(
              key: ValueKey(index),
              // 스와이프 방향
              endActionPane: ActionPane(
                motion: const BehindMotion(),
                // or StretchMotion / DrawerMotion
                children: [
                  // 통화 아이콘
                  SlidableAction(
                    onPressed: (_) => _onTapCall(number),
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    icon: Icons.call,
                    autoClose: false,
                    spacing: 0,
                  ),
                  // 검색 아이콘
                  SlidableAction(
                    onPressed: (_) => _onTapSearch(number),
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    icon: Icons.search,
                    autoClose: false,
                  ),
                  // 편집 아이콘
                  SlidableAction(
                    onPressed: (_) => _onTapEdit(number),
                    backgroundColor: Colors.blueGrey,
                    foregroundColor: Colors.white,
                    icon: Icons.edit,
                    autoClose: false,
                  ),
                ],
              ),
              child: ListTile(
                leading: Icon(iconData, color: iconColor, size: 28),
                title: Text(
                  name.isNotEmpty ? name : number,
                  style: const TextStyle(fontSize: 18), // 폰트 키우기
                ),
                trailing: Text(
                  timeStr,
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // 액션 버튼 로직
  Future<void> _onTapCall(String number) async {
    await NativeMethods.makeCall(number);
  }

  void _onTapSearch(String number) {
    Navigator.pushNamed(context, '/search', arguments: number);
  }

  void _onTapEdit(String number) {
    // ex) 편집 화면
    debugPrint('Tap Edit => $number');
  }
}
