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
import 'package:mobile/widgets/dynamic_call_island.dart';
import 'package:mobile/widgets/floating_call_widget.dart';
import 'package:mobile/providers/call_state_provider.dart';
import 'package:mobile/services/native_methods.dart';
import 'package:mobile/controllers/contacts_controller.dart';

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

  late AppController _appController;
  late ContactsController _contactsController;

  @override
  void initState() {
    super.initState();
    log('[HomeScreen] initState called.');
    WidgetsBinding.instance.addObserver(this);
    _initializeHomeScreen();
    _checkDefaultDialer();
    _loadNotificationCount();
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

  Future<void> _initializeHomeScreen() async {
    log('[HomeScreen] Starting HomeScreen initialization...');
    if (mounted) {
      setState(() {
        _isUiReady = false;
        _uiReadyMessage = '앱 초기화 중...';
      });
    }

    _appController = context.read<AppController>();
    _contactsController = context.read<ContactsController>();

    try {
      NativeDefaultDialerMethods.notifyNativeAppInitialized();
      log('[HomeScreen] Native app initialized notification sent.');
    } catch (e) {
      log('[HomeScreen] Error sending native initialized notification: $e');
    }

    _appController
        .performCoreInitialization()
        .then((_) {
          log(
            '[HomeScreen] AppController core initialization completed (async).',
          );
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

    log('[HomeScreen] Starting contacts load (async)...');
    _contactsController
        .getLocalContacts(forceRefresh: false)
        .then((_) {
          log(
            '[ContactsController] Initial contacts load completed in background.',
          );
        })
        .catchError((e) {
          log('[ContactsController] Error loading initial contacts: $e');
        });

    if (mounted) {
      setState(() {
        _isUiReady = true;
      });
    }
    log(
      '[HomeScreen] UI is ready (Core init & Contacts loading in background).',
    );

    _notificationSub = appEventBus.on<NotificationCountUpdatedEvent>().listen((
      _,
    ) {
      if (mounted) {
        _loadNotificationCount();
      }
    });
    log('[HomeScreen] HomeScreen initialization finished.');
  }

  Future<void> _checkDefaultDialer() async {
    final isDefault = await NativeDefaultDialerMethods.isDefaultDialer();
    if (!mounted) return;
    setState(() => _isDefaultDialer = isDefault);
  }

  Future<void> _loadNotificationCount() async {
    if (!mounted) return;
    final count = Hive.box('notifications').length;
    setState(() {
      _notificationCount = count;
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
            bottom: panelBottomPosition + 70,
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
            bottom: 70.0,
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
