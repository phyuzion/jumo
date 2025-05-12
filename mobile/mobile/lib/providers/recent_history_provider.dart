import 'package:flutter/foundation.dart';
import 'package:mobile/controllers/call_log_controller.dart';
import 'package:mobile/controllers/sms_controller.dart';
import 'dart:developer';

class RecentHistoryProvider with ChangeNotifier {
  final CallLogController callLogController;
  final SmsController smsController;

  List<Map<String, dynamic>> _recentHistoryList = [];
  List<Map<String, dynamic>> get recentHistoryList => _recentHistoryList;

  RecentHistoryProvider({
    required this.callLogController,
    required this.smsController,
  }) {
    callLogController.addListener(_onSourceChanged);
    smsController.addListener(_onSourceChanged);
    _updateRecentHistoryList();
  }

  void _onSourceChanged() {
    _updateRecentHistoryList();
    notifyListeners();
    _uploadNewItemsToServer(); // UI 갱신 후 서버 업로드(비동기)
  }

  void _updateRecentHistoryList() {
    final callLogs = callLogController.callLogs;
    final smsLogs = smsController.smsLogs;
    // 콜로그와 SMS를 합쳐서 시간순(최신순) 정렬
    _recentHistoryList = [
      ...callLogs.map((e) => {...e, 'historyType': 'call'}),
      ...smsLogs.map((e) => {...e, 'historyType': 'sms'}),
    ];
    _recentHistoryList.sort(
      (a, b) => (b['date'] ?? b['timestamp'] ?? 0).compareTo(
        a['date'] ?? a['timestamp'] ?? 0,
      ),
    );
    log(
      '[RecentHistoryProvider] Updated recent history list: ${_recentHistoryList.length} items',
    );
  }

  Future<void> refresh() async {
    await Future.wait([
      callLogController.refreshCallLogs(),
      smsController.refreshSms(),
    ]);
    // _onSourceChanged에서 UI/서버 업로드 처리됨
  }

  void _uploadNewItemsToServer() {
    // TODO: 신규 항목만 서버에 업로드하는 로직 구현 (콜로그/SMS 구분)
    // 이 부분은 각 컨트롤러의 업로드 정책에 맞게 구현 필요
  }

  @override
  void dispose() {
    callLogController.removeListener(_onSourceChanged);
    smsController.removeListener(_onSourceChanged);
    super.dispose();
  }
}
