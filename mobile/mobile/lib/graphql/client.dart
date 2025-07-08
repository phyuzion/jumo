// lib/graphql/client.dart
import 'dart:async'; // TimeoutException 사용 위해 추가
import 'dart:developer';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:dio/dio.dart';
import 'package:gql_dio_link/gql_dio_link.dart';
import 'package:mobile/controllers/navigation_controller.dart';
import 'package:mobile/graphql/user_api.dart';
import 'package:mobile/graphql/setting_api.dart';
import 'package:mobile/repositories/auth_repository.dart';
import 'package:mobile/main.dart';
import 'package:mobile/repositories/notification_repository.dart';
import 'package:mobile/repositories/call_log_repository.dart';
import 'package:mobile/repositories/sms_log_repository.dart';
import 'package:mobile/repositories/blocked_number_repository.dart';
import 'package:mobile/repositories/blocked_history_repository.dart';
import 'package:mobile/repositories/settings_repository.dart';
import 'package:mobile/services/native_methods.dart';
import 'package:mobile/utils/constants.dart';
import 'package:hive_ce/hive.dart';

/// 공통 Endpoint
const String kGraphQLEndpoint = 'https://jumo-vs8e.onrender.com/graphql';
const String kGraphQLHostname = 'jumo-vs8e.onrender.com';
const String kGraphQLPath = '/graphql';

/// GraphQL 통신 공통 로직
class GraphQLClientManager {
  /// AccessToken Getter / Setter (AuthRepository 사용)
  static Future<String?> get accessToken async =>
      await getIt<AuthRepository>().getToken();
  static Future<void> setAccessToken(String? token) async {
    if (token == null) {
      await getIt<AuthRepository>().clearToken();
    } else {
      log('[GraphQL] Saving accessToken via AuthRepository...');
      await getIt<AuthRepository>().setToken(token);
    }
  }

  /// 1) 자동로그인 함수 (id/pw 재로그인)
  static Future<void> tryAutoLogin() async {
    final authRepository = getIt<AuthRepository>();
    final credentials = await authRepository.getSavedCredentials();
    final savedId = credentials['savedLoginId'];
    final savedPw = credentials['password'];

    if (savedId == null ||
        savedId.isEmpty ||
        savedPw == null ||
        savedPw.isEmpty) {
      log('[GraphQL] No saved credentials found for auto-login.');
      return;
    }
    
    try {
      // 전화번호 가져오기 - 항상 디바이스에서 직접 읽어옴
      final String? myNumber = await NativeMethods.getMyPhoneNumber();
      if (myNumber == null || myNumber.isEmpty) {
        log('[GraphQL] No phone number retrieved from device for auto-login.');
        return;
      }
      
      final loginResult = await UserApi.userLogin(
        loginId: savedId,
        password: savedPw,
        phoneNumber: myNumber,
      );
      log('[GraphQL] tryAutoLogin: Re-login API call success.');

      if (loginResult != null && loginResult['user'] is Map) {
        final userData = loginResult['user'] as Map<String, dynamic>;
        final token = loginResult['accessToken'] as String?;

        if (token != null) await authRepository.setToken(token);
        await authRepository.setUserId(userData['id'] ?? '');
        await authRepository.setUserName(userData['name'] ?? '');
        await authRepository.setUserType(userData['userType'] ?? '');
        await authRepository.setLoginStatus(true);
        await authRepository.setUserValidUntil(userData['validUntil'] ?? '');
        await authRepository.setUserRegion(userData['region'] ?? '');
        await authRepository.setUserGrade(userData['grade'] ?? '');

        log('[GraphQL] User info saved via AuthRepository after auto-login.');

        // 자동 로그인 성공 시 디바이스 정보 저장 (비동기로 실행하고 결과를 기다리지 않음)
        try {
          log(
            '[GraphQLClientManager.tryAutoLogin] Saving device info after auto-login',
          );
          SettingApi.saveDeviceInfo(appVersion: APP_VERSION)
              .then((success) {
                log(
                  '[GraphQLClientManager.tryAutoLogin] Device info saved: $success',
                );
              })
              .catchError((e) {
                log(
                  '[GraphQLClientManager.tryAutoLogin] Error saving device info: $e',
                );
              });
        } catch (e) {
          log(
            '[GraphQLClientManager.tryAutoLogin] Error initiating device info save: $e',
          );
        }
      } else {
        log(
          '[GraphQL] Auto-login successful but user data format is unexpected.',
        );
      }
    } catch (e) {
      log('[GraphQL] tryAutoLogin failed during API call or saving: $e');
    }
  }

  // 로그아웃 중인지 추적하는 정적 변수
  static bool _isLoggingOut = false;

  /// 로그아웃 (AuthRepository 및 다른 Box clear)
  static Future<void> logout() async {
    // 이미 로그아웃 중이면 중복 호출 방지
    if (_isLoggingOut) {
      log('[GraphQL] 이미 로그아웃 중입니다. 중복 호출 방지.');
      return;
    }

    _isLoggingOut = true;
    log('[GraphQL] Logging out and clearing user data...');
    try {
      // <<< AuthRepository 완전히 클리어 >>>
      final authRepository = getIt<AuthRepository>();
      await authRepository.setLoginStatus(false);
      // 저장된 ID/PW도 삭제하도록 수정
      await authRepository.clearSavedCredentials(); // ID/PW 정보 삭제
      await authRepository.clearToken(); // 토큰 삭제
      log('[GraphQL] Cleared stored credentials and token via AuthRepository.');

      // <<< NotificationRepository 클리어 >>>
      try {
        final notificationRepository = getIt<NotificationRepository>();
        await notificationRepository.clearAllNotifications();
        log('[GraphQL] Cleared notification data via NotificationRepository.');
      } catch (e) {
        log('[GraphQL] Error clearing notification data: $e');
      }

      // <<< CallLogRepository 클리어 >>>
      try {
        final callLogRepository = getIt<CallLogRepository>();
        await callLogRepository.clearCallLogs();
        log('[GraphQL] Cleared call log data via CallLogRepository.');
      } catch (e) {
        log('[GraphQL] Error clearing call log data: $e');
      }

      // <<< SmsLogRepository 클리어 >>>
      try {
        final smsLogRepository = getIt<SmsLogRepository>();
        await smsLogRepository.clearSmsLogs();
        log('[GraphQL] Cleared SMS log data via SmsLogRepository.');
      } catch (e) {
        log('[GraphQL] Error clearing SMS log data: $e');
      }

      // <<< BlockedNumberRepository 클리어 >>>
      try {
        final blockedNumberRepository = getIt<BlockedNumberRepository>();
        await blockedNumberRepository.clearAllBlockedNumberData();
        log(
          '[GraphQL] Cleared blocked number data via BlockedNumberRepository.',
        );
      } catch (e) {
        log('[GraphQL] Error clearing blocked number data: $e');
      }

      // <<< BlockedHistoryRepository 클리어 >>>
      try {
        final blockedHistoryRepository = getIt<BlockedHistoryRepository>();
        await blockedHistoryRepository.clearBlockedHistory();
        log(
          '[GraphQL] Cleared blocked history data via BlockedHistoryRepository.',
        );
      } catch (e) {
        log('[GraphQL] Error clearing blocked history data: $e');
      }

      // <<< SettingsRepository 차단 설정 초기화 추가 >>>
      try {
        final settingsRepository = getIt<SettingsRepository>();
        await settingsRepository.resetBlockingSettings();
        log('[GraphQL] Blocking settings reset via SettingsRepository.');
      } catch (e) {
        log('[GraphQL] Error resetting blocking settings: $e');
      }

      // <<< Hive 박스 완전 삭제 추가 - 열려있는 박스만 삭제 >>>
      try {
        // 각 박스가 열려있는 경우에만 삭제 시도
        if (Hive.isBoxOpen('auth')) {
          await Hive.box('auth').clear();
          log('[GraphQL] Auth box cleared.');
        }

        if (Hive.isBoxOpen('notifications')) {
          await Hive.box('notifications').clear();
          log('[GraphQL] Notifications box cleared.');
        }

        if (Hive.isBoxOpen('display_noti_ids')) {
          await Hive.box('display_noti_ids').clear();
          log('[GraphQL] Display notification IDs box cleared.');
        }

        if (Hive.isBoxOpen('call_logs')) {
          await Hive.box('call_logs').clear();
          log('[GraphQL] Call logs box cleared.');
        }

        if (Hive.isBoxOpen('sms_logs')) {
          await Hive.box('sms_logs').clear();
          log('[GraphQL] SMS logs box cleared.');
        }

        if (Hive.isBoxOpen('blocked_numbers')) {
          await Hive.box('blocked_numbers').clear();
          log('[GraphQL] Blocked numbers box cleared.');
        }

        if (Hive.isBoxOpen('danger_numbers')) {
          await Hive.box('danger_numbers').clear();
          log('[GraphQL] Danger numbers box cleared.');
        }

        if (Hive.isBoxOpen('bomb_numbers')) {
          await Hive.box('bomb_numbers').clear();
          log('[GraphQL] Bomb numbers box cleared.');
        }

        if (Hive.isBoxOpen('blocked_history')) {
          await Hive.box('blocked_history').clear();
          log('[GraphQL] Blocked history box cleared.');
        }

        if (Hive.isBoxOpen('contacts')) {
          await Hive.box('contacts').clear();
          log('[GraphQL] Contacts box cleared.');
        }

        if (Hive.isBoxOpen('settings')) {
          await Hive.box('settings').clear();
          log('[GraphQL] Settings box cleared.');
        }

        log('[GraphQL] All open Hive boxes have been cleared.');
      } catch (e) {
        log('[GraphQL] Error clearing Hive boxes: $e');
      }

      log('[GraphQL] All user-specific data cleared via repositories.');
    } catch (e) {
      log('[GraphQL] Error clearing data during logout: $e');
    } finally {
      // 로그아웃 상태 초기화
      _isLoggingOut = false;
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
          onRequest: (options, handler) async {
            final token = await accessToken;
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

  /// 자동 로그인 정보 저장 함수 추가 (AuthRepository 사용)
  static Future<void> saveLoginCredentials(
    String id,
    String pw,
    String myNumber,
  ) async {
    final authRepository = getIt<AuthRepository>();
    await authRepository.saveCredentials(id, pw);
    // 전화번호 저장 로직 제거
    log('[GraphQL] Saved login credentials via AuthRepository.');
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
