// lib/screens/home_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mobile/controllers/app_controller.dart';
import 'package:mobile/repositories/notification_repository.dart';
import 'package:mobile/services/native_default_dialer_methods.dart';
import 'package:mobile/widgets/notification_dialog.dart';
import 'package:provider/provider.dart';
import 'package:hive_ce/hive.dart';
import 'package:mobile/utils/app_event_bus.dart';
import 'recent_calls_screen.dart';
import 'contacts_screen.dart';
import 'board_screen.dart';
import 'settings_screen.dart';
import 'dart:developer';
import 'package:mobile/widgets/dynamic_call_island.dart';
import 'package:mobile/widgets/floating_call_widget.dart';
import 'package:mobile/providers/call_state_provider.dart';
import 'package:mobile/services/native_methods.dart';
import 'package:mobile/controllers/contacts_controller.dart';
import 'package:mobile/controllers/phone_state_controller.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:mobile/controllers/blocked_numbers_controller.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _currentIndex = 0;
  int _notificationCount = 0;
  StreamSubscription? _notificationSub;
  bool _isDefaultDialer = false;

  // 서비스 상태 확인 타이머 추가
  Timer? _serviceCheckTimer;
  bool _isServiceRunning = true;

  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();

  final _screens = [
    const RecentCallsScreen(),
    const ContactsScreen(),
    const BoardScreen(),
    const SettingsScreen(),
  ];

  bool _isUiReady = false;
  String _uiReadyMessage = '앱 준비 중...';

  @override
  void initState() {
    super.initState();
    log('[HomeScreen] initState called.');
    WidgetsBinding.instance.addObserver(this);
    _initializeHomeScreen();
    _checkDefaultDialer();
    // 서비스 상태 확인 타이머 시작
    _startServiceCheckTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadNotificationCount();
      _notificationSub = appEventBus.on<NotificationCountUpdatedEvent>().listen(
        (_) {
          if (mounted) {
            _loadNotificationCount();
          }
        },
      );
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _notificationSub?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    // 타이머 정리
    _serviceCheckTimer?.cancel();
    super.dispose();
  }

  // 서비스 상태 확인 타이머 시작
  void _startServiceCheckTimer() {
    _serviceCheckTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _checkAndRestartServiceIfNeeded(),
    );
    log('[HomeScreen] Service check timer started (checks every 2 seconds)');
  }

  // 서비스 상태 확인 및 필요시 재시작
  Future<void> _checkAndRestartServiceIfNeeded() async {
    try {
      final service = FlutterBackgroundService();
      final isRunning = await service.isRunning();

      if (_isServiceRunning != isRunning) {
        setState(() {
          _isServiceRunning = isRunning;
        });
      }

      if (!isRunning) {
        log(
          '[HomeScreen][CRITICAL] Background service is not running, attempting to restart',
        );
        await _restartBackgroundService();
      }
    } catch (e) {
      log('[HomeScreen] Error checking service status: $e');
    }
  }

  // 백그라운드 서비스 재시작
  Future<void> _restartBackgroundService() async {
    try {
      final appController = context.read<AppController>();
      await appController.startBackgroundService();
      log('[HomeScreen] Background service restarted successfully');

      // 서비스 재시작 후 통화 상태 확인
      final phoneStateController = context.read<PhoneStateController>();
      await phoneStateController.syncInitialCallState();
      log('[HomeScreen] Call state synced after service restart');

      setState(() {
        _isServiceRunning = true;
      });
    } catch (e) {
      log('[HomeScreen][CRITICAL] Failed to restart background service: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkDefaultDialer();
      _searchFocusNode.unfocus();
      _loadNotificationCount();
      context.read<ContactsController>().syncContacts();

      // 현재 통화 상태 확인
      final callStateProvider = context.read<CallStateProvider>();
      final currentCallState = callStateProvider.callState;

      // 앱이 resume될 때 통화 중이 아닐 때만 통화 상태 동기화
      if (currentCallState != CallState.active) {
        final phoneStateController = context.read<PhoneStateController>();
        phoneStateController.syncInitialCallState();
        log('[HomeScreen] App resumed, synced call state (not in active call)');
      } else {
        log(
          '[HomeScreen] App resumed, skipped call state sync (in active call)',
        );
      }

      // 캐싱된 상태 확인은 항상 실행 (타이머에 영향 없음)
      _checkCachedCallState();

      // 서비스 상태 확인
      _checkAndRestartServiceIfNeeded();

      log('[HomeScreen] App resumed, updated contacts and UI state.');
    }
  }

  Future<void> _initializeHomeScreen() async {
    log('[HomeScreen] Starting HomeScreen initialization...');
    if (mounted) {
      setState(() {
        _isUiReady = false;
        _uiReadyMessage = '앱 초기화 중...';
      });
    }

    final appController = context.read<AppController>();
    final phoneStateController = context.read<PhoneStateController>();

    await phoneStateController.syncInitialCallState();
    log('[HomeScreen] Initial call state sync attempted.');

    try {
      NativeDefaultDialerMethods.notifyNativeAppInitialized();
      log('[HomeScreen] Native app initialized notification sent.');
    } catch (e) {
      log('[HomeScreen] Error sending native initialized notification: $e');
    }

    try {
      await context.read<BlockedNumbersController>().initialize();
      log(
        '[BlockedNumbers] Initialization completed successfully (local data only)',
      );
    } catch (e) {
      log('[HomeScreen] Error initializing BlockedNumbersController: $e');
    }

    appController
        .performCoreInitialization()
        .then((_) {
          log(
            '[HomeScreen] AppController core initialization completed (async).',
          );
          _setAppInitialized();
          _checkCachedCallState();
        })
        .catchError((e) {
          log(
            '[HomeScreen] Error during AppController core initialization: $e',
          );
          if (mounted) {
            setState(() {
              _uiReadyMessage = '초기화 오류 발생';
            });
          }
        });
    log('[HomeScreen] Requested AppController core initialization.');

    if (mounted) {
      setState(() {
        _isUiReady = true;
      });
    }
    log(
      '[HomeScreen] UI is ready. Contacts loading is managed by ContactsController.',
    );

    log('[HomeScreen] HomeScreen initialization finished.');
  }

  Future<void> _checkDefaultDialer() async {
    final isDefault = await NativeDefaultDialerMethods.isDefaultDialer();
    if (!mounted) return;
    setState(() => _isDefaultDialer = isDefault);
  }

  Future<void> _loadNotificationCount() async {
    if (!mounted) return;
    try {
      // 만료된 알림 제거 (안전장치로 먼저 실행)
      await context.read<NotificationRepository>().removeExpiredNotifications();

      // 모든 알림 가져오기
      final notifications =
          await context.read<NotificationRepository>().getAllNotifications();
      if (mounted) {
        setState(() {
          _notificationCount = notifications.length;
        });
      }
      log('[HomeScreen] Loaded notification count: $_notificationCount');
    } catch (e) {
      log('[HomeScreen] Error loading notification count: $e');
      if (mounted) {
        setState(() {
          _notificationCount = 0;
        });
      }
    }
  }

  void _toggleSearch() {
    final number = _searchController.text.trim();
    if (number.isNotEmpty) {
      Navigator.pushNamed(
        context,
        '/search',
        arguments: {'number': number, 'isRequested': true},
      );
    } else {
      Navigator.pushNamed(context, '/search');
    }
    _searchController.clear();
  }

  void _showNotifications() {
    showDialog(
      context: context,
      builder: (context) => const NotificationDialog(),
    ).then((_) {
      _loadNotificationCount();
    });
  }

  void _toggleCallPopup() {
    context.read<CallStateProvider>().togglePopup();
    log('[HomeScreen] Popup toggle requested.');
  }

  void _handleHangUp() async {
    log('[HomeScreen] Handling hang up...');
    try {
      await NativeMethods.hangUpCall();
    } catch (e) {
      log('[HomeScreen] Error calling native hangUpCall: $e');
    }
    if (mounted) {
      context.read<CallStateProvider>().updateCallState(state: CallState.ended);
    }
  }

  Future<void> _checkCachedCallState() async {
    log('[HomeScreen] Checking for cached call state from background service');
    try {
      final service = FlutterBackgroundService();
      if (await service.isRunning()) {
        service.invoke('checkCachedCallState');
        log(
          '[HomeScreen] Sent checkCachedCallState signal to background service',
        );
      } else {
        log(
          '[HomeScreen] Background service not running, cannot check cached call state',
        );
      }
    } catch (e) {
      log('[HomeScreen] Error checking cached call state: $e');
    }
  }

  Future<void> _setAppInitialized() async {
    log('[HomeScreen] Notifying background service that UI is initialized');
    try {
      final service = FlutterBackgroundService();
      if (await service.isRunning()) {
        service.invoke('appInitialized', {
          'initialized': true,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        });
        log(
          '[HomeScreen] Successfully sent appInitialized signal to background service',
        );
      } else {
        log(
          '[HomeScreen] Background service not running, skipping appInitialized signal',
        );
      }
    } catch (e) {
      log('[HomeScreen] Error sending appInitialized signal: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isUiReady) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(_uiReadyMessage),
            ],
          ),
        ),
      );
    }

    final callStateProvider = context.watch<CallStateProvider>();
    final callState = callStateProvider.callState;
    final number = callStateProvider.number;
    final callerName = callStateProvider.callerName;
    final isConnected = callStateProvider.isConnected;
    final isPopupVisible = callStateProvider.isPopupVisible;
    final duration = callStateProvider.duration;

    final appBar = AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      leading: Padding(
        padding: const EdgeInsets.all(0.0),
        child: Image.asset(
          'icons/app_icon_foreground.webp',
          width: 32,
          height: 32,
        ),
      ),
      titleSpacing: 5,
      title: Text(
        'KOLPON',
        style: TextStyle(
          fontWeight: FontWeight.w500,
          color: Colors.black,
          fontSize: 30,
        ),
      ),
      actions: [
        Stack(
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_rounded, size: 34),
              onPressed: _showNotifications,
            ),
            if (_notificationCount > 0)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 20,
                    minHeight: 20,
                  ),
                  child: Text(
                    _notificationCount.toString(),
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
        // 백그라운드 서비스 상태 인디케이터 추가 (디버깅용)
        if (!_isServiceRunning)
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.red,
                ),
                onPressed: _restartBackgroundService,
              ),
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(45),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  decoration: InputDecoration(
                    hintText: '전화번호 검색',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: Colors.grey.shade300,
                        width: 1,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 0,
                    ),
                  ),
                  keyboardType: TextInputType.phone,
                  showCursor: false,
                  readOnly: false,
                  autofocus: false,
                  onSubmitted: (_) => _toggleSearch(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(Icons.search, size: 30),
                onPressed: _toggleSearch,
              ),
            ],
          ),
        ),
      ),
    );

    final double fabSize = 60.0;
    final double fixedButtonBottomMargin = 16.0;
    final double panelMarginAboveButton = 0.0;
    final double panelBottomPosition =
        fixedButtonBottomMargin + fabSize + panelMarginAboveButton;

    return Stack(
      children: [
        Scaffold(
          appBar: appBar,
          body: Stack(children: [_screens[_currentIndex]]),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (idx) => setState(() => _currentIndex = idx),
            type: BottomNavigationBarType.fixed,
            backgroundColor: Colors.white,
            elevation: 0,
            selectedItemColor: Colors.black,
            unselectedItemColor: Colors.grey,
            showSelectedLabels: true,
            showUnselectedLabels: true,
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.history), label: '최근기록'),
              BottomNavigationBarItem(icon: Icon(Icons.contacts), label: '연락처'),
              BottomNavigationBarItem(
                icon: Icon(Icons.article_outlined),
                label: '게시판',
              ),
              BottomNavigationBarItem(icon: Icon(Icons.settings), label: '설정'),
            ],
          ),
        ),
        if (_isDefaultDialer)
          Positioned(
            top: 60,
            bottom:
                MediaQuery.of(context).padding.bottom +
                panelBottomPosition +
                70,
            left: 16.0,
            right: 16.0,
            child: FloatingCallWidget(
              isVisible: isPopupVisible,
              callState: callState,
              number: number,
              callerName: callerName,
              connected: isConnected,
              duration: duration,
              onClosePopup: _toggleCallPopup,
              onHangUp: _handleHangUp,
            ),
          ),
        if (_isDefaultDialer)
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 56.0 + 16.0,
            right: 16.0,
            child: DynamicCallIsland(
              callState: callState,
              number: number,
              callerName: callerName,
              isPopupVisible: isPopupVisible,
              connected: isConnected,
              endedCountdownSeconds: callStateProvider.endedCountdownSeconds,
              onTogglePopup: _toggleCallPopup,
              duration: duration,
            ),
          ),
      ],
    );
  }
}
