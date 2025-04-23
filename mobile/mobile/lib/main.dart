import 'package:flutter/material.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:mobile/controllers/app_controller.dart';
import 'package:mobile/controllers/blocked_numbers_controller.dart';
import 'package:mobile/controllers/call_log_controller.dart';
import 'package:mobile/controllers/contacts_controller.dart';
import 'package:mobile/controllers/navigation_controller.dart';
import 'package:mobile/controllers/phone_state_controller.dart';
import 'package:mobile/controllers/sms_controller.dart';
import 'package:mobile/deprecated/call_result_overlay.dart';
import 'package:mobile/screens/board_screen.dart';
import 'package:mobile/screens/content_detail_screen.dart';
import 'package:mobile/screens/content_edit_screen.dart';
import 'package:mobile/screens/decider_screen.dart';
import 'package:mobile/screens/login_screen.dart';
import 'package:mobile/screens/home_screen.dart';
import 'package:mobile/screens/search_screen.dart';
import 'package:mobile/deprecated/dialer_screen.dart';
import 'package:mobile/deprecated/incoming_call_screen.dart';
import 'package:mobile/deprecated/on_call_screen.dart';
import 'package:mobile/deprecated/call_ended_screen.dart';
import 'package:mobile/screens/settings_screen.dart';
import 'package:provider/provider.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'dart:developer';
import 'dart:async';

import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart'
    show FlutterQuillLocalizations;
import 'package:mobile/models/blocked_history.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:mobile/providers/call_state_provider.dart';
import 'package:hive_ce/hive.dart';
import 'package:mobile/utils/constants.dart';

/* overlay removed
/// 오버레이 전용 엔트리
@pragma('vm:entry-point')
Future<void> overlayMain() async {
  WidgetsFlutterBinding.ensureInitialized();

  // <<< 오버레이 Isolate 위한 Hive 초기화 >>>
  try {
    final appDocumentDir = await getApplicationDocumentsDirectory();
    await Hive.initFlutter(appDocumentDir.path);
    // 필요한 어댑터 등록
    if (!Hive.isAdapterRegistered(BlockedHistoryAdapter().typeId)) {
      Hive.registerAdapter(BlockedHistoryAdapter());
    }
    log('[overlayMain] Hive initialized successfully.');
  } catch (e) {
    log('[overlayMain] Error initializing Hive: $e');
  }

  runApp(
    MaterialApp(
      home: CallResultOverlay(),
      debugShowCheckedModeBanner: false,
      debugShowMaterialGrid: false,
      theme: ThemeData(
        colorScheme: const ColorScheme.light(
          primary: Colors.black,
          onPrimary: Colors.white,
          surface: Colors.white,
          onSurface: Colors.black,
        ),
        useMaterial3: true,
      ),
      // 텍스트 크기 고정
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(1.0)),
          child: child!,
        );
      },
    ),
  );
}
*/
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  final NotificationAppLaunchDetails? notificationAppLaunchDetails =
      await flutterLocalNotificationsPlugin.getNotificationAppLaunchDetails();
  final String? initialRoutePayload =
      notificationAppLaunchDetails?.notificationResponse?.payload;
  log('[main] App launched with payload: $initialRoutePayload');

  final appDocumentDir = await getApplicationDocumentsDirectory();
  await Hive.initFlutter(appDocumentDir.path);

  // --- 앱 버전 체크 및 Hive 초기화 로직 ---
  const storedAppVersionKey = 'appVersion';
  Box settingsBox; // Box 변수 선언
  try {
    settingsBox = await Hive.openBox('settings'); // 설정 박스 먼저 열기 시도
  } catch (e) {
    log(
      '[AppInit] Failed to open settings box initially, attempting delete and retry: $e',
    );
    // settings box 열기 실패 시 삭제 후 재시도 (파일 손상 등 대비)
    try {
      await Hive.deleteBoxFromDisk('settings');
      settingsBox = await Hive.openBox('settings');
    } catch (e2) {
      log('[AppInit] Failed to open settings box even after delete: $e2');
      // 여기서 앱 실행을 중단하거나 안전 모드로 진입하는 등의 처리 필요
      return;
    }
  }

  final storedVersion = settingsBox.get(storedAppVersionKey) as String?;
  log(
    '[AppInit] Current App Version: $APP_VERSION, Stored Version: $storedVersion',
  );

  if (storedVersion == null || storedVersion != APP_VERSION) {
    log('[AppInit] App version mismatch or first run. Clearing Hive boxes...');
    try {
      // <<< 초기화할 Hive Box 이름 목록 수정 >>>
      const boxNamesToClear = [
        'settings',
        'blocked_history',
        'call_logs',
        'sms_logs',
        'last_sync_state',
        'notifications',
        // 'auth', // <<< 로그인 정보 유지를 위해 제거!
        'display_noti_ids',
        'blocked_numbers',
        'danger_numbers',
        'bomb_numbers',
      ];

      // settingsBox는 이미 열려 있으므로 close 먼저 수행
      await settingsBox.close();

      for (final boxName in boxNamesToClear) {
        log('[AppInit] Deleting Hive box: $boxName');
        try {
          // 개별 박스 삭제 에러 처리
          await Hive.deleteBoxFromDisk(boxName);
        } catch (deleteError) {
          log('[AppInit] Error deleting box $boxName: $deleteError');
          // 특정 박스 삭제 실패 시 로깅만 하고 계속 진행할 수 있음
        }
      }

      // 버전 정보를 저장하기 위해 settings Box 다시 열기
      settingsBox = await Hive.openBox('settings');
      await settingsBox.put(storedAppVersionKey, APP_VERSION);
      log(
        '[AppInit] Hive boxes cleared and current version ($APP_VERSION) stored.',
      );
    } catch (e, st) {
      log('[AppInit] Error clearing Hive boxes: $e\n$st');
    }
  } else {
    log('[AppInit] App version matches. Skipping Hive box clearing.');
  }
  // --- 버전 체크 및 초기화 로직 끝 ---

  // TypeAdapter 등록 (삭제 후 다시 등록 필요 시 여기에 위치하는 것이 안전)
  if (!Hive.isAdapterRegistered(BlockedHistoryAdapter().typeId)) {
    Hive.registerAdapter(BlockedHistoryAdapter());
    log('BlockedHistoryAdapter registered.');
  }

  // ***** 모든 Box 열기 (초기화 과정에서 닫혔을 수 있으므로 다시 열기) *****
  try {
    // settingsBox는 위에서 이미 다시 열었음
    if (!settingsBox.isOpen)
      settingsBox = await Hive.openBox('settings'); // 만약을 위해 isOpen 체크 후 열기
    await Hive.openBox<BlockedHistory>('blocked_history');
    await Hive.openBox('call_logs');
    await Hive.openBox('sms_logs');
    await Hive.openBox('last_sync_state');
    await Hive.openBox('notifications');
    await Hive.openBox('auth');
    await Hive.openBox('display_noti_ids');
    await Hive.openBox('blocked_numbers');
    await Hive.openBox<List<String>>('danger_numbers'); // <<< openBox 추가
    await Hive.openBox<List<String>>('bomb_numbers'); // <<< openBox 추가
    log('All Hive boxes opened successfully in main.');
  } catch (e) {
    log('Error opening Hive boxes in main: $e');
    return;
  }

  // ***** Box 열기 완료 후 컨트롤러 생성 *****
  final contactsController = ContactsController();
  final callLogContoller = CallLogController();
  final smsController = SmsController();
  final blockedNumbersController = BlockedNumbersController(contactsController);
  final phoneStateController = PhoneStateController(
    NavigationController.navKey,
    callLogContoller,
    contactsController,
  );
  // NavigationController 초기화 수정
  await NavigationController.init(
    phoneStateController,
    blockedNumbersController,
    contactsController,
  );
  final appController = AppController(
    phoneStateController,
    contactsController,
    callLogContoller,
    smsController,
    blockedNumbersController,
  );

  runApp(
    MultiProvider(
      providers: [
        Provider<PhoneStateController>.value(value: phoneStateController),
        Provider<AppController>.value(value: appController),
        Provider<SmsController>.value(value: smsController),
        Provider<BlockedNumbersController>.value(
          value: blockedNumbersController,
        ),
        Provider<Box<dynamic>>.value(value: Hive.box('auth')),
        ChangeNotifierProvider.value(value: callLogContoller),
        ChangeNotifierProvider.value(value: contactsController),
        ChangeNotifierProvider(
          create:
              (context) => CallStateProvider(
                context.read<PhoneStateController>(),
                context.read<CallLogController>(),
                context.read<ContactsController>(),
              ),
        ),
      ],
      child: MyAppStateful(initialRoutePayload: initialRoutePayload),
    ),
  );
}

// MyApp을 StatefulWidget으로 변경하여 라이프사이클 감지
class MyAppStateful extends StatefulWidget {
  final String? initialRoutePayload;
  const MyAppStateful({super.key, this.initialRoutePayload});

  @override
  State<MyAppStateful> createState() => _MyAppStatefulState();
}

class _MyAppStatefulState extends State<MyAppStateful>
    with WidgetsBindingObserver {
  StreamSubscription? _updateUiCallStateSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeAppController();
      _handleInitialPayload();
      _listenToBackgroundService();
      _saveScreenSizeToHive();
    });
  }

  Future<void> _initializeAppController() async {
    if (mounted) {
      try {
        final appController = context.read<AppController>();
        await appController.initializeApp();
      } catch (e) {
        log('[MyAppStateful] Error initializing AppController: $e');
      }
    }
  }

  void _handleInitialPayload() {
    final payload = widget.initialRoutePayload;
    if (payload != null) {
      log('[_MyAppStatefulState] Handling initial payload: $payload');
      final provider = context.read<CallStateProvider>();
      final parts = payload.split(':');
      if (parts.length < 1) return;
      final typeStr = parts[0];
      final number = parts.length > 1 ? parts[1] : '';

      CallState? initialState;
      bool initialConnected = false;
      String initialReason = '';

      try {
        initialState = CallState.values.byName(typeStr);
        if (initialState == CallState.active) {
          initialConnected = true;
        } else if (initialState == CallState.ended) {
          initialReason = 'missed';
        }
      } catch (e) {
        log('[_MyAppStatefulState] Error parsing initial CallState: $e');
        initialState = null;
      }

      if (initialState != null && initialState != CallState.idle) {
        log(
          '[_MyAppStatefulState] Setting initial call state from payload: $initialState',
        );
        provider.updateCallState(
          state: initialState,
          number: number,
          callerName: '',
          isConnected: initialConnected,
          reason: initialReason,
        );
      } else {
        log(
          '[_MyAppStatefulState] Initial payload is idle or invalid, starting normally.',
        );
      }
    }
  }

  void _listenToBackgroundService() {
    final service = FlutterBackgroundService();
    _updateUiCallStateSub = service.on('updateUiCallState').listen((event) {
      if (!mounted) return;
      final stateStr = event?['state'] as String?;
      final number = event?['number'] as String? ?? '';
      final callerName = event?['callerName'] as String? ?? '';
      final isConnected = event?['connected'] as bool? ?? false;
      final reason = event?['reason'] as String? ?? '';
      final duration = event?['duration'] as int? ?? 0;

      CallState? newState;
      try {
        if (stateStr != null) {
          newState = CallState.values.byName(stateStr);
        }
      } catch (e) {
        log('[_MyAppStatefulState] Error parsing CallState: $e');
        newState = null;
      }

      if (newState != null) {
        log(
          '[_MyAppStatefulState] Received UI state update from background: $newState',
        );
        context.read<CallStateProvider>().updateCallState(
          state: newState,
          number: number,
          callerName: callerName,
          isConnected: isConnected,
          reason: reason,
          duration: duration,
        );
      } else {
        log(
          '[_MyAppStatefulState] Received invalid state from background: $stateStr',
        );
      }
    });
    log('[_MyAppStatefulState] Listening to background service UI updates.');
  }

  Future<void> _saveScreenSizeToHive() async {
    await Future.delayed(Duration.zero);
    if (!mounted) return;

    try {
      final size = MediaQuery.of(context).size;
      final screenWidth = size.width;
      final screenHeight = size.height;
      log(
        '[_MyAppStatefulState] Saving screen size: Width=$screenWidth, Height=$screenHeight',
      );

      final settingsBox = await Hive.openBox('settings');
      await settingsBox.put('screenWidth', screenWidth);
      await settingsBox.put('screenHeight', screenHeight);
      log('[_MyAppStatefulState] Screen size saved to Hive.');
    } catch (e) {
      log('[_MyAppStatefulState] Error saving screen size to Hive: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _updateUiCallStateSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      log('[MyAppStateful] App resumed. Requesting background sync...');
      try {
        final contactsCtrl = context.read<ContactsController>();
        contactsCtrl.triggerBackgroundSync();
      } catch (e) {
        log('[MyAppStateful] Error getting ContactsController: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: NavigationController.navKey,
      debugShowCheckedModeBanner: false,
      debugShowMaterialGrid: false,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        FlutterQuillLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ko', ''), Locale('en', '')],
      theme: ThemeData(
        colorScheme: const ColorScheme.light(
          primary: Colors.black,
          onPrimary: Colors.white,
          surface: Colors.white,
          onSurface: Colors.black,
        ),
        useMaterial3: true,
      ),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(1.0)),
          child: child!,
        );
      },
      initialRoute: '/decider',
      routes: {
        '/decider': (_) => const DeciderScreen(),
        '/login': (_) => const LoginScreen(),
        '/home': (_) => const HomeScreen(),
        '/search': (ctx) {
          final args = ModalRoute.of(ctx)?.settings.arguments;
          final isRequested =
              args is Map<String, dynamic>
                  ? args['isRequested'] as bool? ?? true
                  : true;
          return SearchScreen(isRequested: isRequested);
        },
        '/settings': (_) => const SettingsScreen(),
        '/dialer': (_) => const DialerScreen(),
        '/incoming': (ctx) {
          final number =
              ModalRoute.of(ctx)?.settings.arguments as String? ?? '';
          return IncomingCallScreen(incomingNumber: number);
        },
        '/onCall': (ctx) {
          final args = ModalRoute.of(ctx)?.settings.arguments;
          String number = '';
          bool connected = false;
          if (args is Map<String, dynamic>) {
            number = args['number'] as String? ?? '';
            connected = args['connected'] as bool? ?? false;
          }
          return OnCallScreen(phoneNumber: number, connected: connected);
        },
        '/callEnded': (ctx) {
          final args = ModalRoute.of(ctx)?.settings.arguments;
          String number = '';
          String reason = '';
          if (args is Map<String, dynamic>) {
            number = args['number'] as String? ?? '';
            reason = args['reason'] as String? ?? '';
          }
          return CallEndedScreen(
            callEndedNumber: number,
            callEndedReason: reason,
          );
        },
        '/board': (_) => const BoardScreen(),
        '/contentDetail': (ctx) {
          final contentId = ModalRoute.of(ctx)?.settings.arguments as String?;
          if (contentId == null) {
            return const Scaffold(body: Center(child: Text('No contentId')));
          }
          return ContentDetailScreen(contentId: contentId);
        },
        '/contentCreate': (ctx) => const ContentEditScreen(item: null),
        '/contentEdit': (ctx) {
          final item =
              ModalRoute.of(ctx)?.settings.arguments as Map<String, dynamic>?;
          return ContentEditScreen(item: item);
        },
      },
    );
  }
}
