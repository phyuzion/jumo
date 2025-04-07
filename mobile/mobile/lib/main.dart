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
import 'package:mobile/screens/dialer_screen.dart';
import 'package:mobile/screens/incoming_call_screen.dart';
import 'package:mobile/screens/on_call_screen.dart';
import 'package:mobile/screens/call_ended_screen.dart';
import 'package:mobile/screens/settings_screen.dart';
import 'package:provider/provider.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'dart:developer';

import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart'
    show FlutterQuillLocalizations;
import 'package:mobile/models/blocked_history.dart';

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
          ).copyWith(textScaler: TextScaler.linear(0.8)),
          child: child!,
        );
      },
    ),
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
  );
  // NavigationController 초기화는 컨트롤러 생성 후
  await NavigationController.init(blockedNumbersController);
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
        Provider<ContactsController>.value(value: contactsController),
        Provider<CallLogController>.value(value: callLogContoller),
        Provider<SmsController>.value(value: smsController),
        Provider<BlockedNumbersController>.value(
          value: blockedNumbersController,
        ),
      ],
      child: const MyAppStateful(),
    ),
  );
}

// MyApp을 StatefulWidget으로 변경하여 라이프사이클 감지
class MyAppStateful extends StatefulWidget {
  const MyAppStateful({super.key});

  @override
  State<MyAppStateful> createState() => _MyAppStatefulState();
}

class _MyAppStatefulState extends State<MyAppStateful>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeAppController();
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

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
