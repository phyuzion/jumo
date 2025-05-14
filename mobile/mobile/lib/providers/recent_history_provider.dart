import 'package:flutter/foundation.dart';
import 'package:mobile/controllers/call_log_controller.dart';
import 'package:mobile/controllers/sms_controller.dart';
import 'package:mobile/controllers/app_controller.dart';
import 'dart:developer';
import 'dart:async';
import 'package:mobile/utils/app_event_bus.dart';

class RecentHistoryProvider with ChangeNotifier {
  final AppController appController;
  final CallLogController callLogController;
  final SmsController smsController;

  List<Map<String, dynamic>> _recentHistoryList = [];
  bool _wasAppLoadingUserData = false;
  StreamSubscription? _callLogUpdatedSubscription;
  StreamSubscription? _smsUpdatedSubscription;

  List<Map<String, dynamic>> get recentHistoryList {
    return _recentHistoryList;
  }

  RecentHistoryProvider({
    required this.appController,
    required this.callLogController,
    required this.smsController,
  }) {
    log(
      '[RecentHistoryProvider.constructor] Instance created. Listening to AppController and EventBus.',
    );
    appController.addListener(_onAppControllerUpdate);
    _wasAppLoadingUserData = appController.isInitialUserDataLoading;

    _callLogUpdatedSubscription = appEventBus.on<CallLogUpdatedEvent>().listen((
      event,
    ) {
      log(
        '[RecentHistoryProvider] Received CallLogUpdatedEvent. Updating history.',
      );
      _updateRecentHistoryListAndNotify();
    });

    // SmsUpdatedEvent도 이벤트 버스로 처리한다면 아래와 같이 구독
    // _smsUpdatedSubscription = appEventBus.on<SmsUpdatedEvent>().listen((event) {
    //   log('[RecentHistoryProvider] Received SmsUpdatedEvent. Updating history.');
    //   _updateRecentHistoryListAndNotify();
    // });

    _updateRecentHistoryList();
  }

  void _onAppControllerUpdate() {
    final currentAppLoadingState = appController.isInitialUserDataLoading;

    if (_wasAppLoadingUserData && !currentAppLoadingState) {
      log(
        '[RecentHistoryProvider._onAppControllerUpdate] Initial user data loading finished. Updating history.',
      );
      _updateRecentHistoryListAndNotify();
    } else if (!currentAppLoadingState && !_wasAppLoadingUserData) {
      // 이 경우는 AppController.requestUiUpdate() 호출 시 (예: SMS 이벤트 후)
      log(
        '[RecentHistoryProvider._onAppControllerUpdate] AppController requested UI update (e.g., from SMS). Updating history.',
      );
      _updateRecentHistoryListAndNotify();
    }
    _wasAppLoadingUserData = currentAppLoadingState;
  }

  // _updateRecentHistoryList와 notifyListeners를 합친 헬퍼 함수
  void _updateRecentHistoryListAndNotify() {
    _updateRecentHistoryList();
    notifyListeners();
  }

  void _updateRecentHistoryList() {
    if (appController.isInitialUserDataLoading && _recentHistoryList.isEmpty) {
      return;
    }
    final callLogs = callLogController.callLogs;
    final smsLogs = smsController.smsLogs;

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
      '[RecentHistoryProvider._updateRecentHistoryList] List updated. Count: ${_recentHistoryList.length}',
    );
  }

  Future<void> refresh() async {
    log(
      '[RecentHistoryProvider.refresh] Triggering AppController.triggerContactsLoadIfReady.',
    );
    await appController.triggerContactsLoadIfReady();
  }

  @override
  void dispose() {
    log(
      '[RecentHistoryProvider.dispose] Called. Removing listeners and subscriptions.',
    );
    appController.removeListener(_onAppControllerUpdate);
    _callLogUpdatedSubscription?.cancel();
    _smsUpdatedSubscription?.cancel();
    super.dispose();
    log('[RecentHistoryProvider.dispose] Finished.');
  }
}
