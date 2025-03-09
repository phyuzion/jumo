import 'package:flutter/foundation.dart';
import 'package:get_storage/get_storage.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

/// 서버 GraphQL Endpoint
const String _graphqlEndpoint = 'https://jumo-vs8e.onrender.com/graphql';

/// GraphQL API 모음
///
/// - userLogin
/// - userChangePassword
/// - updatePhoneLog
/// - updateSMSLog
///
/// AccessToken 은 GetStorage('accessToken') 에 저장/로드
class JumoGraphQLApi {
  // GetStorage 인스턴스
  static final GetStorage _box = GetStorage();

  // AccessToken을 box에 보관 (null이면 remove)
  static String? get accessToken => _box.read<String>('accessToken');
  static set accessToken(String? token) {
    if (token == null) {
      _box.remove('accessToken');
    } else {
      _box.write('accessToken', token);
    }
  }

  /// GraphQL Client 생성
  /// - 요청 시 AccessToken 을 Authorization 헤더로 첨부
  static GraphQLClient get _client {
    final HttpLink httpLink = HttpLink(_graphqlEndpoint);

    final AuthLink authLink = AuthLink(
      // AccessToken 이 있으면 "Bearer <토큰>" 헤더 추가
      getToken: () => (accessToken == null) ? null : 'Bearer ${accessToken!}',
    );

    final Link link = authLink.concat(httpLink);

    return GraphQLClient(cache: GraphQLCache(), link: link);
  }

  // --------------------------------------------------
  // 1) userLogin
  // --------------------------------------------------
  static const String _userLoginMutation = r'''
    mutation userLogin($loginId: String!, $password: String!, $phoneNumber: String!) {
      userLogin(loginId: $loginId, password: $password, phoneNumber: $phoneNumber) {
        accessToken
        refreshToken
      }
    }
  ''';

  /// 로그인
  /// - 성공 시 accessToken 을 GetStorage('accessToken') 에 저장
  static Future<void> userLogin({
    required String loginId,
    required String password,
    required String phoneNumber,
  }) async {
    final MutationOptions options = MutationOptions(
      document: gql(_userLoginMutation),
      variables: {
        'loginId': loginId,
        'password': password,
        'phoneNumber': phoneNumber,
      },
    );

    final result = await _client.mutate(options);
    if (result.hasException) {
      debugPrint(result.exception.toString());
      // GraphQL 에러메시지 추출
      final msg =
          result.exception?.graphqlErrors.isNotEmpty == true
              ? result.exception!.graphqlErrors.first.message
              : '로그인 실패';
      throw Exception('로그인 실패: $msg');
    }

    final data = result.data?['userLogin'];
    if (data == null) {
      throw Exception('로그인 응답이 올바르지 않습니다');
    }

    final token = data['accessToken'] as String?;
    // refreshToken = data['refreshToken'];

    if (token == null) {
      throw Exception('accessToken이 null입니다');
    }

    // 토큰 보관
    accessToken = token;
    debugPrint('[userLogin] accessToken=$token');
  }

  // --------------------------------------------------
  // 2) userChangePassword
  // --------------------------------------------------
  static const String _userChangePasswordMutation = r'''
    mutation userChangePassword($oldPassword:String!, $newPassword:String!){
      userChangePassword(oldPassword:$oldPassword, newPassword:$newPassword){
        success
        user {
          id
          name
          phoneNumber
        }
      }
    }
  ''';

  /// 비밀번호 변경
  /// - AccessToken 이 있어야 호출 가능
  static Future<bool> userChangePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    if (accessToken == null) {
      throw Exception('로그인 필요: accessToken이 없습니다.');
    }

    final MutationOptions options = MutationOptions(
      document: gql(_userChangePasswordMutation),
      variables: {'oldPassword': oldPassword, 'newPassword': newPassword},
    );

    final result = await _client.mutate(options);
    if (result.hasException) {
      debugPrint(result.exception.toString());
      final msg =
          result.exception?.graphqlErrors.isNotEmpty == true
              ? result.exception!.graphqlErrors.first.message
              : '비밀번호 변경 실패';
      throw Exception('비밀번호 변경 실패: $msg');
    }

    final data = result.data?['userChangePassword'];
    if (data == null) {
      throw Exception('비밀번호 변경 응답이 올바르지 않습니다');
    }
    final success = data['success'] as bool? ?? false;
    return success;
  }

  // --------------------------------------------------
  // 3) updatePhoneLog
  // --------------------------------------------------
  static const String _updatePhoneLogMutation = r'''
    mutation updatePhoneLog($userId:ID!, $logs:[PhoneLogInput!]!){
      updatePhoneLog(userId:$userId, logs:$logs)
    }
  ''';

  /// 통화내역 업로드
  /// logs 예시: [
  ///   {"phoneNumber":"0101234","time":"1696000123456","callType":"IN"},
  ///   ...
  /// ]
  static Future<bool> updatePhoneLog({
    required String userId,
    required List<Map<String, dynamic>> logs,
  }) async {
    if (accessToken == null) {
      throw Exception('로그인 필요: accessToken이 없습니다.');
    }

    final MutationOptions options = MutationOptions(
      document: gql(_updatePhoneLogMutation),
      variables: {'userId': userId, 'logs': logs},
    );

    final result = await _client.mutate(options);
    if (result.hasException) {
      debugPrint(result.exception.toString());
      final msg =
          result.exception?.graphqlErrors.isNotEmpty == true
              ? result.exception!.graphqlErrors.first.message
              : '통화내역 업로드 실패';
      throw Exception('통화내역 업로드 실패: $msg');
    }

    final updated = result.data?['updatePhoneLog'] as bool? ?? false;
    return updated;
  }

  // --------------------------------------------------
  // 4) updateSMSLog
  // --------------------------------------------------
  static const String _updateSMSLogMutation = r'''
    mutation updateSMSLog($userId:ID!, $logs:[SMSLogInput!]!){
      updateSMSLog(userId:$userId, logs:$logs)
    }
  ''';

  /// 문자내역 업로드
  /// logs 예시: [
  ///   {"phoneNumber":"0105678","time":"1696000123456","content":"Hello","smsType":"OUT"},
  ///   ...
  /// ]
  static Future<bool> updateSMSLog({
    required String userId,
    required List<Map<String, dynamic>> logs,
  }) async {
    if (accessToken == null) {
      throw Exception('로그인 필요: accessToken이 없습니다.');
    }

    final MutationOptions options = MutationOptions(
      document: gql(_updateSMSLogMutation),
      variables: {'userId': userId, 'logs': logs},
    );

    final result = await _client.mutate(options);
    if (result.hasException) {
      debugPrint(result.exception.toString());
      final msg =
          result.exception?.graphqlErrors.isNotEmpty == true
              ? result.exception!.graphqlErrors.first.message
              : '문자내역 업로드 실패';
      throw Exception('문자내역 업로드 실패: $msg');
    }

    final updated = result.data?['updateSMSLog'] as bool? ?? false;
    return updated;
  }

  /// 로그아웃 시 AccessToken 제거
  static void logout() {
    accessToken = null;
  }
}
