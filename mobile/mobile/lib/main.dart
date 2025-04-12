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
import 'package:mobile/overlay/call_result_overlay.dart';
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

/// 오버레이 전용 엔트리
@pragma('vm:entry-point')
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();

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

void main() async {
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

  // TypeAdapter 등록
  if (!Hive.isAdapterRegistered(BlockedHistoryAdapter().typeId)) {
    Hive.registerAdapter(BlockedHistoryAdapter());
    log('BlockedHistoryAdapter registered.');
  }

  // ***** 모든 Box 열기를 먼저 완료 *****
  try {
    await Hive.openBox('settings');
    await Hive.openBox<BlockedHistory>('blocked_history');
    await Hive.openBox('call_logs');
    await Hive.openBox('sms_logs');
    await Hive.openBox('last_sync_state');
    await Hive.openBox('notifications');
    await Hive.openBox('auth');
    await Hive.openBox('display_noti_ids');
    await Hive.openBox('blocked_numbers');
    log('All Hive boxes opened successfully in main.');
  } catch (e) {
    log('Error opening Hive boxes in main: $e');
    // Box 열기 실패 시 앱 실행 중단 또는 오류 처리 필요
    return; // 예: 앱 실행 중단
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
