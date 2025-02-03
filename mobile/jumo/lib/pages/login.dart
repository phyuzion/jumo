import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../graphql/mutations.dart';
import '../util/constants.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final TextEditingController _userIdController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final box = GetStorage();

  bool _isConnected = false;
  bool _tryLogin = true;
  bool _isLoggingIn = false; // for future use
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
  }

  /// 인터넷 연결 상태만 체크합니다.
  Future<void> _checkConnectivity() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult != ConnectivityResult.none) {
      setState(() {
        _isConnected = true;
      });
      _attemptAutoLogin();
    } else {
      setState(() {
        _isConnected = false;
        _tryLogin = false;
      });
      showToast('인터넷 연결이 필요합니다.');
    }
  }

  /// 로컬 저장소에 저장된 User ID와 전화번호가 있으면 자동 로그인 시도합니다.
  Future<void> _attemptAutoLogin() async {
    final storedUserId = box.read(USER_ID_KEY) ?? '';
    final storedPhone = box.read(USER_PHONE_KEY) ?? '';
    if (storedUserId.toString().isNotEmpty &&
        storedPhone.toString().isNotEmpty) {
      _userIdController.text = storedUserId;
      _phoneController.text = storedPhone;
      _login();
    } else {
      setState(() {
        _tryLogin = false;
      });
    }
  }

  /// GraphQL 뮤테이션을 사용하여 로그인 요청을 수행합니다.
  Future<void> _login() async {
    setState(() {
      _isLoggingIn = true;
      _errorMessage = null;
    });

    final String userId = _userIdController.text.trim();
    final String phone = _phoneController.text.trim();

    if (userId.isEmpty || phone.isEmpty) {
      setState(() {
        _errorMessage = 'User ID와 전화번호를 모두 입력하세요.';
        _isLoggingIn = false;
      });
      showToast('User ID와 전화번호를 모두 입력하세요.');
      return;
    }

    // GraphQL 뮤테이션 옵션 설정
    final MutationOptions options = MutationOptions(
      document: gql(CLIENT_LOGIN),
      variables: {'userId': userId, 'phone': phone},
    );

    final client = GraphQLProvider.of(context).value;
    try {
      final result = await client.mutate(options);
      if (result.hasException) {
        setState(() {
          _errorMessage = result.exception.toString();
          _isLoggingIn = false;
        });
        showToast('로그인 실패');
      } else {
        final response = result.data?['clientLogin'];
        final bool success = response['success'] ?? false;
        if (success && response['user'] != null) {
          showToast('로그인 성공');
          // 저장: User ID, 전화번호, ValidUntil 등 필요한 정보
          box.write(USER_ID_KEY, userId);
          box.write(USER_PHONE_KEY, phone);
          box.write(USER_EXPIRE, response['user']['validUntil']); // ISO string
          box.write(USER_NAME, response['user']['name']);
          // ignore: use_build_context_synchronously
          Navigator.of(context).pushReplacementNamed('/main');
        } else {
          setState(() {
            _errorMessage = '로그인 실패: 잘못된 사용자 정보';
            _isLoggingIn = false;
          });
          showToast('로그인 실패');
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoggingIn = false;
      });
      showToast('로그인 에러: ${e.toString()}');
    }
  }

  @override
  void dispose() {
    _userIdController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child:
              _isConnected
                  ? _tryLogin
                      ? const CircularProgressIndicator()
                      : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // 로고 이미지
                          Image.asset(
                            'assets/images/logo.png',
                            width: 150,
                            height: 150,
                          ),
                          const SizedBox(height: 20),
                          TextField(
                            controller: _userIdController,
                            textAlign: TextAlign.center,
                            decoration: InputDecoration(
                              hintText: '아이디를 입력하세요.',
                              fillColor: Colors.grey[200],
                              filled: true,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(5.0),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 15,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _phoneController,
                            textAlign: TextAlign.center,
                            decoration: InputDecoration(
                              hintText: '전화번호를 입력하세요.',
                              fillColor: Colors.grey[200],
                              filled: true,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(5.0),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 15,
                              ),
                            ),
                            keyboardType: TextInputType.phone,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _login,
                            child: const Text('로그인'),
                          ),
                          if (_errorMessage != null) ...[
                            const SizedBox(height: 16),
                            Text(
                              _errorMessage!,
                              style: const TextStyle(color: Colors.red),
                            ),
                          ],
                        ],
                      )
                  : OutlinedButton(
                    onPressed: _checkConnectivity,
                    child: const Text(
                      '인터넷 연결이 필요합니다.',
                      style: TextStyle(color: Colors.black),
                    ),
                  ),
        ),
      ),
    );
  }
}
