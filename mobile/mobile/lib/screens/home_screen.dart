// lib/screens/home_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mobile/controllers/app_controller.dart';
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
import 'package:mobile/screens/dialer_screen.dart';
import 'package:mobile/widgets/dynamic_call_island.dart';
import 'package:mobile/widgets/floating_call_widget.dart';

// <<< 새로운 커스텀 위젯 임포트 (파일 생성 후) >>>
// import 'package:mobile/widgets/dynamic_call_interface.dart';
// <<< 임시 상태 정의 (추후 별도 파일/Notifier로 분리) >>>
enum CallState { idle, incoming, active, ended }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _currentIndex = 0;
  Box get _notificationsBox => Hive.box('notifications');
  int _notificationCount = 0;
  StreamSubscription? _notificationSub;
  bool _isDefaultDialer = false;

  // <<< 통화 상태 및 팝업 표시 상태 관리 >>>
  CallState _currentCallState = CallState.idle;
  String _currentNumber = '';
  String _currentCallerName = '';
  int _currentDuration = 0;
  bool _isCallPopupVisible = false;
  // TODO: Provider/Notifier로 상태 관리 이전하고, 백그라운드 서비스 이벤트 리스너 추가하여 상태 업데이트

  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();

  final _screens = [
    const RecentCallsScreen(),
    const ContactsScreen(),
    const BoardScreen(),
    const SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _checkDefaultDialer();

    NativeDefaultDialerMethods.notifyNativeAppInitialized();
    log('[HomeScreen] Native app initialized notification sent.');

    _loadNotificationCount();
    _notificationSub = appEventBus.on<NotificationCountUpdatedEvent>().listen((
      _,
    ) {
      if (mounted) {
        _loadNotificationCount();
      }
    });

    // TODO: Listen to background service event ('updateUiCallState') here
    // FlutterBackgroundService().on('updateUiCallState').listen((event) {
    //   setState(() {
    //      _currentCallState = parseState(event?['state']);
    //      _currentNumber = event?['number'] ?? '';
    //      // ... etc ...
    //      if (_currentCallState == CallState.ended) {
    //         _isCallPopupVisible = false; // 통화 종료 시 팝업 자동 닫기
    //         // TODO: 30초 후 idle 상태로 변경 타이머?
    //      }
    //   });
    // });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _notificationSub?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkDefaultDialer();
      _searchFocusNode.unfocus();
      _loadNotificationCount();
    }
  }

  Future<void> _checkDefaultDialer() async {
    final isDefault = await NativeDefaultDialerMethods.isDefaultDialer();
    if (!mounted) return;
    setState(() => _isDefaultDialer = isDefault);
  }

  void _loadNotificationCount() {
    if (!mounted) return;

    setState(() {
      _notificationCount = _notificationsBox.length;
    });
    log('[HomeScreen] Loaded notification count: $_notificationCount');
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

  // <<< 팝업 토글 함수 (임시: Incoming 상태 테스트용) >>>
  void _toggleCallPopup() {
    setState(() {
      // 현재 상태가 이미 incoming이면 idle로, 아니면 incoming으로 설정
      if (_currentCallState == CallState.incoming) {
        _currentCallState = CallState.idle;
        _currentNumber = '';
        _currentCallerName = '';
        _isCallPopupVisible = false; // idle이면 팝업 닫기
      } else {
        _currentCallState = CallState.incoming;
        _currentNumber = '010-8923-6835'; // 임시 번호
        _currentCallerName = '테스트 수신자'; // 임시 이름
        _isCallPopupVisible = !_isCallPopupVisible; // 팝업 상태 토글
      }
      log(
        '[HomeScreen] Test state set to: $_currentCallState, Popup: $_isCallPopupVisible',
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final appController = context.watch<AppController>();
    // <<< AppBar 정의 (높이 계산 위해 먼저 정의) >>>
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

    // <<< 필요한 높이/마진 값 계산 >>>
    final double appBarHeight =
        appBar.preferredSize.height +
        (appBar.bottom?.preferredSize.height ?? 0);
    final double panelTopMargin = 16.0;
    final double fabSize = 60.0;
    final double fixedButtonBottomMargin = 16.0;
    final double panelMarginAboveButton = 0.0;
    final double panelBottomPosition =
        fixedButtonBottomMargin + fabSize + panelMarginAboveButton;
    final double statusBarHeight = MediaQuery.of(context).padding.top;

    // <<< 최상위를 Stack으로 변경 >>>
    return Stack(
      children: [
        // --- 1. 기본 Scaffold UI ---
        Scaffold(
          appBar: appBar,
          body: Stack(
            // 로딩 인디케이터 등 Scaffold body 내용
            children: [
              _screens[_currentIndex],
              ValueListenableBuilder<bool>(
                valueListenable: appController.isInitializingNotifier,
                builder: (context, isInitializing, child) {
                  if (!isInitializing) return const SizedBox.shrink();
                  return Container(
                    color: Colors.black.withOpacity(0.5),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(),
                            const SizedBox(height: 16),
                            Text(
                              appController.initializationMessage,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
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

        // --- 2. 팝업 패널 (FloatingCallWidget) ---
        Positioned(
          top: 60,
          bottom: panelBottomPosition + 70,
          left: 16.0,
          right: 16.0,
          child: FloatingCallWidget(
            isVisible: _isCallPopupVisible,
            callState: _currentCallState,
            number: _currentNumber,
            callerName: _currentCallerName,
            duration: _currentDuration,
            onClosePopup: _toggleCallPopup,
          ),
        ),

        // --- 3. 하단 버튼/바 (DynamicCallIsland) ---
        if (_isDefaultDialer)
          Positioned(
            bottom: 70.0,
            right: 16.0,
            child: DynamicCallIsland(
              callState: _currentCallState,
              number: _currentNumber,
              callerName: _currentCallerName,
              isPopupVisible: _isCallPopupVisible,
              onTogglePopup: _toggleCallPopup,
            ),
          ),
      ],
    );
  }
}
