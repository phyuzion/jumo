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
    log(
      '[RecentHistoryProvider.recentHistoryList_getter] Called. Returning ${_recentHistoryList.length} items.',
    );
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
        '[RecentHistoryProvider] Received CallLogUpdatedEvent from EventBus. Updating history.',
      );
      _updateRecentHistoryList();
      notifyListeners();
    });

    _updateRecentHistoryList();
    log('[RecentHistoryProvider.constructor] Finished.');
  }

  void _onAppControllerUpdate() {
    log(
      '[RecentHistoryProvider._onAppControllerUpdate] AppController notified.',
    );
    final currentAppLoadingState = appController.isInitialUserDataLoading;

    if (_wasAppLoadingUserData && !currentAppLoadingState) {
      log(
        '[RecentHistoryProvider._onAppControllerUpdate] Initial user data loading finished. Updating recent history.',
      );
      _updateRecentHistoryList();
      notifyListeners();
    } else if (!currentAppLoadingState && !_wasAppLoadingUserData) {
      log(
        '[RecentHistoryProvider._onAppControllerUpdate] AppController requested UI update (e.g., from SMS event). Updating recent history.',
      );
      _updateRecentHistoryList();
      notifyListeners();
    } else if (currentAppLoadingState && !_wasAppLoadingUserData) {
      log(
        '[RecentHistoryProvider._onAppControllerUpdate] Initial user data loading started.',
      );
    }
    _wasAppLoadingUserData = currentAppLoadingState;
  }

  void _updateRecentHistoryList() {
    log('[RecentHistoryProvider._updateRecentHistoryList] Started.');
    if (appController.isInitialUserDataLoading && _recentHistoryList.isEmpty) {
      log(
        '[RecentHistoryProvider._updateRecentHistoryList] AppController is loading initial user data and list is empty, skipping update for now to prevent stale data view.',
      );
      return;
    }
    final callLogs = callLogController.callLogs;
    final smsLogs = smsController.smsLogs;
    log(
      '[RecentHistoryProvider._updateRecentHistoryList] Fetched ${callLogs.length} call logs and ${smsLogs.length} SMS logs.',
    );

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
      '[RecentHistoryProvider._updateRecentHistoryList] Sorted list. Final recent history list count: ${_recentHistoryList.length}',
    );
    log('[RecentHistoryProvider._updateRecentHistoryList] Finished.');
  }

  Future<void> refresh() async {
    log(
      '[RecentHistoryProvider.refresh] Started. Triggering AppController.triggerContactsLoadIfReady.',
    );
    await appController.triggerContactsLoadIfReady();
    log(
      '[RecentHistoryProvider.refresh] Finished (AppController was triggered).',
    );
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
