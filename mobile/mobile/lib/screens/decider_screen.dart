// lib/screens/decider_screen.dart
import 'dart:developer';

import 'package:flutter/material.dart';
// import 'package:get_storage/get_storage.dart'; // 제거
// import 'package:hive_ce/hive.dart'; // <<< 제거
import 'package:mobile/controllers/app_controller.dart';
import 'package:mobile/repositories/auth_repository.dart'; // <<< 추가
import 'package:mobile/services/native_methods.dart';
import 'package:mobile/utils/constants.dart';
import 'package:provider/provider.dart';
import 'package:mobile/graphql/user_api.dart'; // 추가: UserApi import
import 'package:mobile/graphql/client.dart'; // 추가: GraphQLClientManager import

class DeciderScreen extends StatefulWidget {
  const DeciderScreen({super.key});

  @override
  State<DeciderScreen> createState() => _DeciderScreenState();
}

class _DeciderScreenState extends State<DeciderScreen> {
  bool _checkingPermissions = true; // 권한 확인 중 상태
  bool _permissionsGranted = false; // 모든 필수 권한 부여 여부

  // final box = GetStorage(); // 제거
  // Box get _authBox => Hive.box('auth'); // <<< 제거

  @override
  void initState() {
    super.initState();
    _checkInitialStatusAndNavigate(); // 함수 이름 변경으로 명확성 증대
  }

  Future<void> _checkInitialStatusAndNavigate() async {
    if (!mounted) return;
    // 초기에는 항상 확인 중 상태
    if (!_checkingPermissions) {
      // 이미 확인 완료 후 재요청 등으로 다시 불린 경우가 아니라면
      setState(() => _checkingPermissions = true);
    }

    final appController = context.read<AppController>();
    final authRepository = context.read<AuthRepository>();

    // 1. 필수 권한 확인 및 요청
    final bool essentialPermissionsOk =
        await appController.checkEssentialPermissions();
    if (!mounted) return;

    if (essentialPermissionsOk) {
      // 권한이 확보되었으므로 _permissionsGranted를 true로 설정
      setState(() => _permissionsGranted = true);
      log('[DeciderScreen] All essential permissions granted.');

      // 2. 권한 OK -> 저장된 로그인 정보 확인하여 강제로 새 로그인 시도
      final credentials = await authRepository.getSavedCredentials();
      final savedId = credentials['savedLoginId'];
      final savedPw = credentials['password'];
      final myNumber = await authRepository.getMyNumber();

      // 로그인 정보가 있으면 무조건 새로 로그인 시도
      if (savedId != null &&
          savedId.isNotEmpty &&
          savedPw != null &&
          savedPw.isNotEmpty &&
          myNumber != null &&
          myNumber.isNotEmpty) {
        log('[DeciderScreen] Stored credentials found. Forcing new login...');

        try {
          // UserApi를 통해 새로운 로그인 시도
          final loginResult = await UserApi.userLogin(
            loginId: savedId,
            password: savedPw,
            phoneNumber: myNumber,
          );

          // 로그인 성공 확인
          if (loginResult != null &&
              loginResult['user'] is Map &&
              loginResult['accessToken'] != null) {
            log('[DeciderScreen] Forced login successful. Navigating to home.');

            if (!mounted) return;
            // 로그인 성공 시 연락처 로드 시작
            await appController.triggerContactsLoadIfReady();
            Navigator.pushReplacementNamed(context, '/home');
          } else {
            log(
              '[DeciderScreen] Forced login failed. Invalid response format.',
            );
            Navigator.pushReplacementNamed(context, '/login');
          }
        } catch (e) {
          // 로그인 실패 - 계정 만료 등의 이유
          log('[DeciderScreen] Forced login failed with error: $e');
          // 로그인 실패 시 기존 토큰과 로그인 상태 초기화
          await GraphQLClientManager.logout();
          if (!mounted) return;
          Navigator.pushReplacementNamed(context, '/login');
        }
      } else {
        // 저장된 로그인 정보가 없음
        log(
          '[DeciderScreen] No stored credentials. Navigating to login screen.',
        );
        Navigator.pushReplacementNamed(context, '/login');
      }
    } else {
      log('[DeciderScreen] Essential permissions NOT granted.');
      // 권한 거부 상태 UI 표시를 위해 상태 업데이트
      if (mounted) {
        setState(() {
          _checkingPermissions = false;
          _permissionsGranted = false;
        });
      }
    }
    // 네비게이션이 발생하지 않은 경우 (예: 권한 거부)에만 _checkingPermissions를 false로 설정
    // 네비게이션이 발생하면 이 위젯은 unmount되므로 setState 호출 불필요/오류 유발 가능
    // 위의 essentialPermissionsOk == false 분기에서 이미 처리됨.
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingPermissions) {
      // 권한 확인 중 로딩 UI
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('앱 초기화 및 권한 확인 중...'),
            ],
          ),
        ),
      );
    }

    if (!_permissionsGranted) {
      // 권한 확인 완료 후, 권한이 없는 경우 재요청 UI
      return Scaffold(
        appBar: AppBar(title: const Text('권한 요청')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                '앱 사용을 위해 다음 필수 권한이 필요합니다:\n[전화, 주소록, SMS 등].\n권한을 허용해주세요.',
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _checkInitialStatusAndNavigate, // 권한 재요청
                child: const Text('권한 다시 요청하기'),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () {
                  /* TODO: 앱 종료 또는 다른 안내 */
                },
                child: const Text('앱 종료', style: TextStyle(color: Colors.grey)),
              ),
            ],
          ),
        ),
      );
    }

    // 모든 조건이 충족되어 네비게이션이 이미 발생했어야 함.
    // 이 지점은 이론적으로 도달하지 않아야 하지만, 만약을 위해 로딩 표시
    log(
      '[DeciderScreen] Reached unexpected state in build method (should have navigated).',
    );
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
        ),
      ),
    );
  }
}
