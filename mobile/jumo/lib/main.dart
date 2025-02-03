import 'package:flutter/material.dart';

import 'package:get_storage/get_storage.dart';
import 'package:jumo/pages/latestPage.dart';
import 'package:jumo/pages/searchPage.dart';
import 'pages/login.dart';

import 'package:graphql_flutter/graphql_flutter.dart';

import 'util/constants.dart';
import 'controllers/controller.dart';
import 'pages/account.dart';
import 'overlay/overlay.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await GetStorage.init();

  // GraphQL Client 초기화
  final HttpLink httpLink = HttpLink(GRAPHQL_URL);

  final GraphQLClient client = GraphQLClient(
    link: httpLink,
    cache: GraphQLCache(store: InMemoryStore()),
  );

  final ValueNotifier<GraphQLClient> clientNotifier = ValueNotifier(client);

  runApp(GraphQLProvider(client: clientNotifier, child: const MyApp()));
}

@pragma("vm:entry-point")
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const MaterialApp(debugShowCheckedModeBanner: false, home: OverlayView()),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  final String _appTitle = APP_NAME;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: _appTitle,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.orangeAccent),
        useMaterial3: true,
      ),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(1.0)), // 텍스트 크기 고정
          child: child!,
        );
      },
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginPage(),
        '/main': (context) => const Controller(),
        '/account': (context) => const AccountPage(),
        '/latest': (context) => const LatestPage(),
        '/search': (context) => const SearchPage(),
      },
    );
  }
}
