import 'package:flutter/foundation.dart';
import 'package:mobile/controllers/call_log_controller.dart';
import 'package:mobile/controllers/sms_controller.dart';
import 'dart:developer';

class RecentHistoryProvider with ChangeNotifier {
  final CallLogController callLogController;
  final SmsController smsController;

  List<Map<String, dynamic>> _recentHistoryList = [];
  List<Map<String, dynamic>> get recentHistoryList {
    log(
      '[RecentHistoryProvider.recentHistoryList_getter] Called. Returning ${_recentHistoryList.length} items.',
    );
    return _recentHistoryList;
  }

  RecentHistoryProvider({
    required this.callLogController,
    required this.smsController,
  }) {
    log(
      '[RecentHistoryProvider.constructor] Instance created. Adding listeners and calling _updateRecentHistoryList.',
    );
    callLogController.addListener(_onSourceChanged);
    smsController.addListener(_onSourceChanged);
    _updateRecentHistoryList(); // 초기 데이터 구성
    log('[RecentHistoryProvider.constructor] Finished.');
  }

  void _onSourceChanged() {
    log(
      '[RecentHistoryProvider._onSourceChanged] Called due to source controller change.',
    );
    _updateRecentHistoryList();
    log('[RecentHistoryProvider._onSourceChanged] Before notifyListeners.');
    notifyListeners();
    // _uploadNewItemsToServer(); // UI 갱신 후 서버 업로드(비동기) - 현재 구현 안됨
    log('[RecentHistoryProvider._onSourceChanged] Finished.');
  }

  void _updateRecentHistoryList() {
    log('[RecentHistoryProvider._updateRecentHistoryList] Started.');
    final callLogs = callLogController.callLogs; // Getter 호출
    final smsLogs = smsController.smsLogs; // Getter 호출
    log(
      '[RecentHistoryProvider._updateRecentHistoryList] Fetched ${callLogs.length} call logs and ${smsLogs.length} SMS logs.',
    );

    _recentHistoryList = [
      ...callLogs.map((e) => {...e, 'historyType': 'call'}),
      ...smsLogs.map((e) => {...e, 'historyType': 'sms'}),
    ];
    log(
      '[RecentHistoryProvider._updateRecentHistoryList] Combined list has ${_recentHistoryList.length} items before sort.',
    );
    _recentHistoryList.sort(
      (a, b) => (b['date'] ?? b['timestamp'] ?? 0).compareTo(
        a['date'] ?? a['timestamp'] ?? 0,
      ),
    );
    log(
      '[RecentHistoryProvider._updateRecentHistoryList] Sorted list. Final recent history list count: ${_recentHistoryList.length}',
    );
    log('[RecentHistoryProvider._updateRecentHistoryList] Finished.');
  }

  Future<void> refresh() async {
    log('[RecentHistoryProvider.refresh] Started.');
    // 각 컨트롤러의 refresh 메소드 호출 시, 해당 컨트롤러 내부에서 이미 로그가 찍힘
    await Future.wait([
      callLogController.refreshCallLogs(),
      smsController.refreshSms(),
    ]);
    // _onSourceChanged는 각 컨트롤러의 notifyListeners에 의해 자동으로 호출됨.
    // 따라서 여기서 _updateRecentHistoryList나 notifyListeners를 직접 호출할 필요 없음.
    log('[RecentHistoryProvider.refresh] Finished.');
  }

  void _uploadNewItemsToServer() {
    log(
      '[RecentHistoryProvider._uploadNewItemsToServer] Called (Not Implemented).',
    );
    // TODO: 신규 항목만 서버에 업로드하는 로직 구현 (콜로그/SMS 구분)
    // 이 부분은 각 컨트롤러의 업로드 정책에 맞게 구현 필요
  }

  @override
  void dispose() {
    log('[RecentHistoryProvider.dispose] Called. Removing listeners.');
    callLogController.removeListener(_onSourceChanged);
    smsController.removeListener(_onSourceChanged);
    super.dispose();
    log('[RecentHistoryProvider.dispose] Finished.');
  }
}
