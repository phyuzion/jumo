// lib/graphql/client.dart
import 'dart:async'; // TimeoutException 사용 위해 추가
import 'dart:developer';
import 'package:hive_ce/hive.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:dio/dio.dart';
import 'package:gql_dio_link/gql_dio_link.dart';
import 'package:mobile/controllers/navigation_controller.dart';
import 'package:mobile/graphql/user_api.dart';
import 'package:mobile/models/blocked_history.dart';

/// 공통 Endpoint
const String kGraphQLEndpoint = 'https://jumo-vs8e.onrender.com/graphql';
const String kGraphQLHostname = 'jumo-vs8e.onrender.com';
const String kGraphQLPath = '/graphql';

/// GraphQL 통신 공통 로직
class GraphQLClientManager {
  // GetStorage 인스턴스 제거
  static Box get _authBox => Hive.box('auth');

  /// AccessToken Getter / Setter
  static String? get accessToken => _authBox.get('accessToken') as String?;
  static set accessToken(String? token) {
    if (token == null) {
      _authBox.delete('accessToken');
    } else {
      log('[GraphQL] Saving accessToken to Hive...');
      _authBox.put('accessToken', token);
    }
  }

  // ===============================
  // 1) 자동로그인 함수 (id/pw 재로그인)
  static Future<void> tryAutoLogin() async {
    final savedId = _authBox.get('savedLoginId') as String?;
    final savedPw = _authBox.get('savedPassword') as String?;
    final myNumber = _authBox.get('myNumber') as String?;

    if (savedId == null ||
        savedId.isEmpty ||
        savedPw == null ||
        savedPw.isEmpty ||
        myNumber == null ||
        myNumber.isEmpty) {
      log('[GraphQL] No saved credentials found for auto-login.');
      await logout();
    } else {
      try {
        final loginResult = await UserApi.userLogin(
          loginId: savedId,
          password: savedPw,
          phoneNumber: myNumber,
        );
        log(
          '[GraphQL] tryAutoLogin: Re-login success with $savedId, $myNumber',
        );
      } catch (e) {
        log('[GraphQL] tryAutoLogin failed: $e');
        await logout();
      }
    }
  }

  /// 로그아웃 (Hive 데이터 삭제)
  static Future<void> logout() async {
    log('[GraphQL] Logging out and clearing user data...');
    try {
      await Hive.box('auth').clear();
      await Hive.box('notifications').clear();
      await Hive.box('last_sync_state').clear();
      await Hive.box<BlockedHistory>('blocked_history').clear();
      await Hive.box('call_logs').clear();
      await Hive.box('sms_logs').clear();
      await Hive.box('display_noti_ids').clear();
      await Hive.box('blocked_numbers').clear();
      log('[GraphQL] Cleared user-specific Hive boxes.');
    } catch (e) {
      log('[GraphQL] Error clearing Hive boxes during logout: $e');
    }
    NavigationController.goToDecider();
  }

  // --- 싱글톤 및 초기화 로직 ---
  static GraphQLClient? _clientInstance;
  static Dio? _dioInstance;

  // client getter (동기 방식 복구)
  static GraphQLClient get client {
    if (_clientInstance != null) return _clientInstance!;

    log('[GraphQL] Initializing GraphQL client (first time)...');

    // Dio 클라이언트 생성 (한 번만)
    _dioInstance ??= Dio(
      BaseOptions(
        // baseUrl 제거
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 30),
      ),
    );

    // HttpClientAdapter 설정 제거 (SSL 오류 처리 제거)
    // (_dioInstance!.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () { ... };

    // 인터셉터 설정 (한 번만)
    if (_dioInstance!.interceptors.whereType<InterceptorsWrapper>().isEmpty) {
      _dioInstance!.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            final token = accessToken;
            if (token != null) {
              options.headers['Authorization'] = 'Bearer $token';
            }
            options.extra['startTime'] = Stopwatch()..start();
            // 상세 로그 필요 시 활성화
            // log('[DioInterceptor] Requesting: ${options.method} ${options.uri} Headers: ${options.headers}');
            return handler.next(options);
          },
          onResponse: (response, handler) {
            final stopwatch =
                response.requestOptions.extra['startTime'] as Stopwatch?;
            if (stopwatch != null) {
              stopwatch.stop();
              log(
                '[DioInterceptor] Response: ${response.statusCode} took: ${stopwatch.elapsedMilliseconds}ms URI: ${response.requestOptions.uri}',
              );
            }
            return handler.next(response);
          },
          onError: (DioException e, handler) {
            final stopwatch = e.requestOptions.extra['startTime'] as Stopwatch?;
            if (stopwatch != null) {
              stopwatch.stop();
              log(
                '[DioInterceptor] Error took: ${stopwatch.elapsedMilliseconds}ms URI: ${e.requestOptions.uri}',
              );
            }
            log('[DioInterceptor] Error: ${e.type} - ${e.message}');
            return handler.next(e);
          },
        ),
      );
      log('[GraphQL] Dio interceptor added.');
    }

    // gql_dio_link 사용 (원래 엔드포인트)
    final link = DioLink(
      kGraphQLEndpoint,
      client: _dioInstance!,
    ); // Dio 인스턴스 전달

    _clientInstance = GraphQLClient(cache: GraphQLCache(), link: link);
    log(
      '[GraphQL] GraphQL client initialized successfully using endpoint: $kGraphQLEndpoint',
    );
    return _clientInstance!;
  }

  /// 자동 로그인 정보 저장 함수 추가
  static Future<void> saveLoginCredentials(
    String id,
    String pw,
    String myNumber,
  ) async {
    await _authBox.put('savedLoginId', id);
    await _authBox.put('savedPassword', pw);
    await _authBox.put('myNumber', myNumber);
    log('[GraphQL] Saved login credentials to Hive.');
  }

  /// 헬퍼: GraphQL Exception 핸들링
  ///  - 서버 GraphQLError가 있을 경우, 메시지 추출
  static Future<void> handleExceptions(QueryResult result) async {
    log(
      '[GraphQL] handleExceptions called. Exception object: ${result.exception}',
    ); // 예외 객체 직접 로깅

    // result.hasException 대신 result.exception 존재 여부로 판단
    if (result.exception != null) {
      final exceptionString = result.exception.toString();
      log('[GraphQL] Exception details: $exceptionString'); // 예외 상세 내용 로깅

      // TimeoutException 문자열 포함 여부로 더 확실하게 체크
      if (exceptionString.contains('TimeoutException')) {
        log(
          '[GraphQL] TimeoutException detected (via string search), ignoring.',
        );
        return; // 타임아웃은 무시하고 종료
      }

      // --- 기존 로그인 필요 및 기타 오류 처리 ---
      if (result.exception?.graphqlErrors.isNotEmpty == true) {
        final msg = result.exception!.graphqlErrors.first.message;
        if (msg.contains('로그인이 필요합니다')) {
          log(
            '[GraphQL] Authentication error detected, attempting auto-login...',
          );
          await tryAutoLogin();
          return; // 로그인 시도 후 종료
        }
        log('[GraphQL] GraphQL Error: $msg');
        // throw Exception(msg);
      } else if (result.exception?.linkException != null) {
        final linkErr = result.exception!.linkException.toString();
        log('[GraphQL] LinkException: $linkErr');
        // throw Exception('GraphQL LinkException: $linkErr');
      } else {
        log('[GraphQL] Unknown GraphQL exception: ${result.exception}');
        // throw Exception('GraphQL unknown exception');
      }
      // --- 오류 처리 끝 ---
    } else if (result.data == null) {
      log('[GraphQL] handleExceptions: result.data is null, but no exception.');
    } else {
      // 예외 없고 데이터도 있는 정상 케이스
      log('[GraphQL] handleExceptions: No exception detected.');
    }
  }
}
