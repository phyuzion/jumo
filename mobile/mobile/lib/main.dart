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
import 'package:mobile/repositories/auth_repository.dart';
import 'package:get_it/get_it.dart';
import 'package:mobile/repositories/settings_repository.dart';
import 'package:mobile/repositories/notification_repository.dart';
import 'package:mobile/repositories/call_log_repository.dart';
import 'package:mobile/repositories/sms_log_repository.dart';
import 'package:mobile/repositories/blocked_number_repository.dart';
import 'package:mobile/repositories/blocked_history_repository.dart';
import 'package:mobile/repositories/sync_state_repository.dart';

final getIt = GetIt.instance;

Future<void> initializeDependencies() async {
  log('[initializeDependencies] Starting...');
  final appDocumentDir = await getApplicationDocumentsDirectory();
  await Hive.initFlutter(appDocumentDir.path);
  log('[initializeDependencies] Hive initialized.');

  if (!Hive.isAdapterRegistered(BlockedHistoryAdapter().typeId)) {
    Hive.registerAdapter(BlockedHistoryAdapter());
    log('[initializeDependencies] BlockedHistoryAdapter registered.');
  }

  try {
    final authBox = await Hive.openBox('auth');
    final authRepository = HiveAuthRepository(authBox);
    if (!getIt.isRegistered<AuthRepository>()) {
      getIt.registerSingleton<AuthRepository>(authRepository);
    }
    log('[initializeDependencies] AuthRepository registered in GetIt.');
  } catch (e) {
    log(
      '[initializeDependencies] FATAL: Error initializing AuthRepository: $e',
    );
    rethrow;
  }

  try {
    final settingsBox = await Hive.openBox('settings');
    final settingsRepository = HiveSettingsRepository(settingsBox);
    if (!getIt.isRegistered<SettingsRepository>()) {
      getIt.registerSingleton<SettingsRepository>(settingsRepository);
    }
    log('[initializeDependencies] SettingsRepository registered in GetIt.');
  } catch (e) {
    log(
      '[initializeDependencies] FATAL: Error initializing SettingsRepository: $e',
    );
    rethrow;
  }

  try {
    final notificationsBox = await Hive.openBox('notifications');
    final displayNotiIdsBox = await Hive.openBox('display_noti_ids');
    final notificationRepository = HiveNotificationRepository(
      notificationsBox,
      displayNotiIdsBox,
    );
    if (!getIt.isRegistered<NotificationRepository>()) {
      getIt.registerSingleton<NotificationRepository>(notificationRepository);
    }
    log('[initializeDependencies] NotificationRepository registered in GetIt.');
  } catch (e) {
    log(
      '[initializeDependencies] FATAL: Error initializing NotificationRepository: $e',
    );
    rethrow;
  }

  try {
    final callLogsBox = await Hive.openBox('call_logs');
    final callLogRepository = HiveCallLogRepository(callLogsBox);
    if (!getIt.isRegistered<CallLogRepository>()) {
      getIt.registerSingleton<CallLogRepository>(callLogRepository);
    }
    log('[initializeDependencies] CallLogRepository registered in GetIt.');
  } catch (e) {
    log(
      '[initializeDependencies] FATAL: Error initializing CallLogRepository: $e',
    );
    rethrow;
  }

  try {
    final smsLogsBox = await Hive.openBox('sms_logs');
    final smsLogRepository = HiveSmsLogRepository(smsLogsBox);
    if (!getIt.isRegistered<SmsLogRepository>()) {
      getIt.registerSingleton<SmsLogRepository>(smsLogRepository);
    }
    log('[initializeDependencies] SmsLogRepository registered in GetIt.');
  } catch (e) {
    log(
      '[initializeDependencies] FATAL: Error initializing SmsLogRepository: $e',
    );
    rethrow;
  }

  try {
    final blockedNumbersBox = await Hive.openBox('blocked_numbers');
    final dangerNumbersBox = await Hive.openBox<List<String>>('danger_numbers');
    final bombNumbersBox = await Hive.openBox<List<String>>('bomb_numbers');
    final blockedNumberRepository = HiveBlockedNumberRepository(
      blockedNumbersBox,
      dangerNumbersBox,
      bombNumbersBox,
    );
    if (!getIt.isRegistered<BlockedNumberRepository>()) {
      getIt.registerSingleton<BlockedNumberRepository>(blockedNumberRepository);
    }
    log(
      '[initializeDependencies] BlockedNumberRepository registered in GetIt.',
    );
  } catch (e) {
    log(
      '[initializeDependencies] FATAL: Error initializing BlockedNumberRepository: $e',
    );
    rethrow;
  }

  try {
    final blockedHistoryBox = await Hive.openBox<BlockedHistory>(
      'blocked_history',
    );
    final blockedHistoryRepository = HiveBlockedHistoryRepository(
      blockedHistoryBox,
    );
    if (!getIt.isRegistered<BlockedHistoryRepository>()) {
      getIt.registerSingleton<BlockedHistoryRepository>(
        blockedHistoryRepository,
      );
    }
    log(
      '[initializeDependencies] BlockedHistoryRepository registered in GetIt.',
    );
  } catch (e) {
    log(
      '[initializeDependencies] FATAL: Error initializing BlockedHistoryRepository: $e',
    );
    rethrow;
  }

  try {
    final syncStateBox = await Hive.openBox('last_sync_state');
    final syncStateRepository = HiveSyncStateRepository(syncStateBox);
    if (!getIt.isRegistered<SyncStateRepository>()) {
      getIt.registerSingleton<SyncStateRepository>(syncStateRepository);
    }
    log('[initializeDependencies] SyncStateRepository registered in GetIt.');
  } catch (e) {
    log(
      '[initializeDependencies] FATAL: Error initializing SyncStateRepository: $e',
    );
    rethrow;
  }

  try {
    await Future.wait([
      // Hive.openBox('last_sync_state'),
    ]);
    log('[initializeDependencies] Other Hive boxes opened.');
  } catch (e) {
    log(
      '[initializeDependencies] Warning: Error opening some other Hive boxes: $e',
    );
  }
  log('[initializeDependencies] Finished.');
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await initializeDependencies();
  } catch (e) {
    log('[main] Critical initialization failed: $e');
    runApp(
      MaterialApp(home: Scaffold(body: Center(child: Text('앱 초기화 실패: $e')))),
    );
    return;
  }

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  final NotificationAppLaunchDetails? notificationAppLaunchDetails =
      await flutterLocalNotificationsPlugin.getNotificationAppLaunchDetails();
  final String? initialRoutePayload =
      notificationAppLaunchDetails?.notificationResponse?.payload;
  log('[main] App launched with payload: $initialRoutePayload');

  final authRepository = getIt<AuthRepository>();
  final settingsRepository = getIt<SettingsRepository>();
  final notificationRepository = getIt<NotificationRepository>();
  final callLogRepository = getIt<CallLogRepository>();
  final smsLogRepository = getIt<SmsLogRepository>();
  final blockedNumberRepository = getIt<BlockedNumberRepository>();
  final blockedHistoryRepository = getIt<BlockedHistoryRepository>();
  final syncStateRepository = getIt<SyncStateRepository>();
  final callLogContoller = CallLogController(callLogRepository);
  final contactsController = ContactsController();
  final smsController = SmsController(settingsRepository, smsLogRepository);
  final blockedNumbersController = BlockedNumbersController(
    contactsController,
    settingsRepository,
    blockedNumberRepository,
    blockedHistoryRepository,
  );
  final phoneStateController = PhoneStateController(
    NavigationController.navKey,
    callLogContoller,
    contactsController,
  );
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
    notificationRepository,
  );

  runApp(
    MultiProvider(
      providers: [
        Provider<AuthRepository>.value(value: authRepository),
        Provider<SettingsRepository>.value(value: settingsRepository),
        Provider<NotificationRepository>.value(value: notificationRepository),
        Provider<PhoneStateController>.value(value: phoneStateController),
        Provider<AppController>.value(value: appController),
        Provider<SmsController>.value(value: smsController),
        Provider<BlockedNumbersController>.value(
          value: blockedNumbersController,
        ),
        ChangeNotifierProvider<CallLogController>.value(
          value: callLogContoller,
        ),
        ChangeNotifierProvider.value(value: contactsController),
        ChangeNotifierProvider(
          create:
              (context) => CallStateProvider(
                context.read<PhoneStateController>(),
                context.read<CallLogController>(),
                context.read<ContactsController>(),
              ),
        ),
        Provider<CallLogRepository>.value(value: callLogRepository),
        Provider<SmsLogRepository>.value(value: smsLogRepository),
        Provider<BlockedNumberRepository>.value(value: blockedNumberRepository),
        Provider<BlockedHistoryRepository>.value(
          value: blockedHistoryRepository,
        ),
        Provider<SyncStateRepository>.value(value: syncStateRepository),
      ],
      child: MyAppStateful(initialRoutePayload: initialRoutePayload),
    ),
  );
}

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

      final settingsRepository = context.read<SettingsRepository>();
      await settingsRepository.setScreenWidth(screenWidth);
      await settingsRepository.setScreenHeight(screenHeight);
      log('[_MyAppStatefulState] Screen size saved via SettingsRepository.');
    } catch (e) {
      log('[_MyAppStatefulState] Error saving screen size via Repository: $e');
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
