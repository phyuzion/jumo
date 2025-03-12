import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:get_storage/get_storage.dart';
import 'package:mobile/controllers/app_controller.dart';
import 'package:mobile/graphql/client.dart';
import 'package:mobile/graphql/user_api.dart';
import 'package:mobile/services/native_default_dialer_methods.dart';
import 'package:mobile/utils/constants.dart'; // formatDateString
import 'package:provider/provider.dart'; // optional if needed

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with WidgetsBindingObserver {
  bool _checking = false;
  bool _isDefaultDialer = false;
  bool _overlayGranted = false;

  /// 유저 정보
  late String _phoneNumber; // 내 휴대폰번호
  late String _loginId; // 아이디
  late String _userName; // 이름
  late String _validUntil; // 만료일(문자열)

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final box = GetStorage();

    // 1) 저장된 유저정보 읽어오기
    _phoneNumber = box.read<String>('myNumber') ?? '(unknown)';
    _loginId = box.read<String>('savedLoginId') ?? '(no id)';
    _userName = box.read<String>('userName') ?? '(no name)';

    final rawValidUntil = box.read<String>(
      'userValidUntil',
    ); // 예: "1689730000" or ISO
    _validUntil = formatDateString(rawValidUntil ?? '');

    // 2) 현재 기본 전화앱인지 / 오버레이권한 인지 체크
    _checkStatus();
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
      // 앱이 다시 전면으로 돌아왔을 때 오버레이 권한 재확인
      _checkStatus();
    }
  }

  Future<void> _checkStatus() async {
    setState(() => _checking = true);

    // (A) 기본 전화앱 여부
    final defDialer = await NativeDefaultDialerMethods.isDefaultDialer();

    // (B) 오버레이 권한 여부
    final overlayOk = await FlutterOverlayWindow.isPermissionGranted();

    if (overlayOk) {
      final appController = context.read<AppController>();
      //      appController.initOverlayOnce();
    }

    if (!mounted) return;
    setState(() {
      _checking = false;
      _isDefaultDialer = defDialer;
      _overlayGranted = overlayOk;
    });
  }

  /// 기본 전화앱 등록
  Future<void> _onRequestDefaultDialer() async {
    final ok = await NativeDefaultDialerMethods.requestDefaultDialerManually();
    // ok == true 면 등록됨
    // 재확인
    final defDialer = await NativeDefaultDialerMethods.isDefaultDialer();
    if (!mounted) return;
    setState(() {
      _isDefaultDialer = defDialer;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_isDefaultDialer ? '기본 전화앱 등록됨' : '등록 안됨')),
    );
  }

  /// 오버레이 권한
  Future<void> _onRequestOverlayPermission() async {
    final granted = await FlutterOverlayWindow.isPermissionGranted();
    if (granted) {
      final appController = context.read<AppController>();
      //   appController.initOverlayOnce();

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('이미 권한 허용됨')));
      return;
    }
    final result = await FlutterOverlayWindow.requestPermission();
    if (!mounted) return;

    if (result == true) {
      setState(() => _overlayGranted = true);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('오버레이 권한 허용됨')));
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('오버레이 권한 거부됨')));
    }
  }

  /// 비밀번호 변경
  Future<void> _onChangePassword() async {
    final oldPwCtrl = TextEditingController();
    final newPwCtrl = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('비밀번호 변경'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: oldPwCtrl,
                  decoration: const InputDecoration(labelText: '기존 비번'),
                  obscureText: true,
                ),
                TextField(
                  controller: newPwCtrl,
                  decoration: const InputDecoration(labelText: '새 비번'),
                  obscureText: true,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('취소'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('확인'),
              ),
            ],
          ),
    );
    if (result != true) return;

    final oldPw = oldPwCtrl.text.trim();
    final newPw = newPwCtrl.text.trim();
    if (oldPw.isEmpty || newPw.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('비밀번호 입력이 필요합니다.')));
      return;
    }

    try {
      final success = await UserApi.userChangePassword(
        oldPassword: oldPw,
        newPassword: newPw,
      );
      if (success) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('비밀번호 변경 성공!')));
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('비밀번호 변경 실패..')));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('오류: $e')));
    }
  }

  /// 로그아웃
  Future<void> _onLogout() async {
    GraphQLClientManager.logout();
    //NavigationController.goToDecider();
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: AppBar(title: const Text('설정/계정정보')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.phone_android),
            title: const Text('내 휴대폰번호'),
            subtitle: Text(_phoneNumber),
          ),
          ListTile(
            leading: const Icon(Icons.account_circle),
            title: const Text('내 아이디'),
            subtitle: Text(_loginId),
          ),
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text('내 이름'),
            subtitle: Text(_userName),
          ),
          ListTile(
            leading: const Icon(Icons.timer),
            title: const Text('만료일'),
            subtitle: Text(_validUntil),
          ),
          const Divider(),

          // 기본 전화앱 등록
          SwitchListTile(
            secondary: const Icon(Icons.phone),
            title: const Text('기본 전화앱 등록'),
            subtitle: Text(_isDefaultDialer ? '이미 등록됨' : '아직 미등록'),
            value: _isDefaultDialer,
            onChanged: (val) {
              if (!val) {
                // 기본 전화앱 해지? 안드로이드상 해제는 복잡. 보통 OS 설정에서
                // 여기서는 아무것도 안 함
              } else {
                _onRequestDefaultDialer();
              }
            },
          ),

          // 오버레이 권한
          SwitchListTile(
            secondary: const Icon(Icons.window),
            title: const Text('오버레이 권한'),
            subtitle: Text(_overlayGranted ? '허용됨' : '미허용 (수신전화 팝업용)'),
            value: _overlayGranted,
            onChanged: (val) {
              _onRequestOverlayPermission();
            },
          ),

          const Divider(),

          // 비밀번호 변경
          ListTile(
            leading: const Icon(Icons.lock),
            title: const Text('비밀번호 변경'),
            onTap: _onChangePassword,
          ),

          // 로그아웃
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('로그아웃'),
            onTap: _onLogout,
          ),
        ],
      ),
    );
  }
}
