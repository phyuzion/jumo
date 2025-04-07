import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:hive_ce/hive.dart';
import 'package:mobile/controllers/blocked_numbers_controller.dart';
import 'package:mobile/controllers/update_controller.dart';
import 'package:mobile/graphql/client.dart';
import 'package:mobile/graphql/user_api.dart';
import 'package:mobile/models/blocked_history.dart';
import 'package:mobile/services/native_default_dialer_methods.dart';
import 'package:mobile/utils/constants.dart';
import 'package:mobile/widgets/dropdown_menus_widet.dart'; // formatDateString
import 'package:mobile/widgets/blocked_numbers_dialog.dart';
import 'package:mobile/widgets/blocked_history_dialog.dart';
import 'package:provider/provider.dart';
import 'package:mobile/controllers/app_controller.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with WidgetsBindingObserver {
  /// 상태: 로딩중(체크중)
  bool _checking = false;

  /// 기본 전화앱 여부
  bool _isDefaultDialer = false;

  /// 오버레이 권한 여부
  bool _overlayGranted = false;

  /// 유저 정보
  String _phoneNumber = '(unknown)';
  String _loginId = '(no id)';
  String _userName = '(no name)';
  String _userRegion = '(no region)';
  String _validUntil = '';
  String _userGrade = '일반';

  // 업데이트 관련
  String _serverVersion = ''; // 서버에서 조회한 버전
  bool get _updateAvailable =>
      _serverVersion.isNotEmpty && _serverVersion != APP_VERSION;

  // 차단 설정 컨트롤러
  late final BlockedNumbersController _blockedNumbersController;

  // 콜폭 차단 횟수 입력 컨트롤러
  late final TextEditingController _bombCallsCountController;

  // Hive Box 사용
  Box get _authBox => Hive.box('auth');

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    // Hive에서 유저 정보 읽어오기
    _loadUserInfo();

    _checkStatus();
    _checkVersionManually();

    // 3) 차단 설정 컨트롤러 초기화
    _blockedNumbersController = context.read<BlockedNumbersController>();

    // 4) 콜폭 차단 횟수 입력 컨트롤러 초기화
    _bombCallsCountController = TextEditingController(
      text: _blockedNumbersController.bombCallsCount.toString(),
    );
  }

  /// (A) 업데이트 체크(수동)
  Future<void> _checkVersionManually() async {
    final updateCtrl = UpdateController();
    final ver = await updateCtrl.getServerVersion();
    if (!mounted) return;
    setState(() {
      _serverVersion = ver;
    });
  }

  /// (B) [업데이트] 버튼을 누를 때
  Future<void> _onTapUpdate() async {
    final updateCtrl = UpdateController();
    await updateCtrl.downloadAndInstallApk();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _bombCallsCountController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // 앱이 다시 전면으로 돌아왔을 때 오버레이 권한 재확인
      _checkStatus();

      // 차단 리스트 업데이트
      _blockedNumbersController.initialize().then((_) {
        if (mounted) {
          setState(() {});
        }
      });
    }
  }

  Future<void> _checkStatus() async {
    setState(() => _checking = true);

    // (A) 기본 전화앱 여부
    final defDialer = await NativeDefaultDialerMethods.isDefaultDialer();

    // (B) 오버레이 권한 여부
    final overlayOk = await FlutterOverlayWindow.isPermissionGranted();

    if (!mounted) return;
    setState(() {
      _checking = false;
      _isDefaultDialer = defDialer;
      _overlayGranted = overlayOk;
    });
  }

  /// 기본 전화앱 등록
  Future<void> _onRequestDefaultDialer() async {
    await NativeDefaultDialerMethods.requestDefaultDialerManually();
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
    final result = await FlutterOverlayWindow.requestPermission();
    // result == true 면 성공
    if (!mounted) return;
    if (result == true) {
      setState(() => _overlayGranted = true);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('팝업 권한 허용됨')));
    } else {
      setState(() => _overlayGranted = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('팝업 권한 거부됨')));
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

  void _showBlockedNumbersDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const BlockedNumbersDialog(),
    ).then((_) {
      if (!mounted) return;
      setState(() {});
    });
  }

  void _showBlockedHistoryDialog(
    BuildContext context,
    List<BlockedHistory> history,
  ) {
    showDialog(
      context: context,
      builder: (context) => BlockedHistoryDialog(history: history),
    );
  }

  // Hive에서 사용자 정보 로드 메소드 추가
  void _loadUserInfo() {
    // 기본값을 사용하여 안전하게 로드
    _phoneNumber = _authBox.get('myNumber', defaultValue: '(unknown)');
    _loginId = _authBox.get('savedLoginId', defaultValue: '(no id)');
    _userName = _authBox.get('userName', defaultValue: '(no name)');
    _userRegion = _authBox.get('userRegion', defaultValue: '(no region)');
    _userGrade = _authBox.get('userGrade', defaultValue: '일반');
    final rawValidUntil =
        _authBox.get('userValidUntil', defaultValue: '') as String;
    _validUntil = formatDateString(rawValidUntil);
    // setState는 initState에서 불필요
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(40),
        child: AppBar(
          title: Text(
            '설정',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          actions: [const DropdownMenusWidget()],
        ),
      ),
      body: ListView(
        children: [
          // (1) 만약 서버 버전이 내 버전과 다르면 => "업데이트가 있습니다." 버튼
          if (_updateAvailable)
            ListTile(
              title: const Text(
                '업데이트가 있습니다!',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
              subtitle: Text('서버 버전: $_serverVersion\n현재 버전: $APP_VERSION'),
              trailing: ElevatedButton(
                onPressed: _onTapUpdate,
                child: const Text('업데이트'),
              ),
            ),
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
            leading: const Icon(Icons.star),
            title: const Text('내 등급'),
            subtitle: Text(_userGrade),
          ),
          ListTile(
            leading: const Icon(Icons.map),
            title: const Text('내 지역'),
            subtitle: Text(_userRegion),
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
                // 기본 전화앱 해지? 아무것도 안 함
              } else {
                _onRequestDefaultDialer();
              }
            },
          ),

          if (_isDefaultDialer) ...[
            const Divider(),

            ListTile(
              leading: const Icon(Icons.block),
              title: const Text('차단 설정'),
              subtitle: Text('차단 설정을 변경할 수 있습니다.'),
            ),

            SwitchListTile(
              title: Padding(
                padding: const EdgeInsets.only(left: 16.0),
                child: const Text('오늘 상담 차단'),
              ),
              value: _blockedNumbersController.isTodayBlocked,
              onChanged: (value) async {
                await _blockedNumbersController.setTodayBlocked(value);
                if (!mounted) return;
                setState(() {});
              },
            ),
            SwitchListTile(
              title: Padding(
                padding: const EdgeInsets.only(left: 16.0),
                child: const Text('모르는번호 차단'),
              ),
              value: _blockedNumbersController.isUnknownBlocked,
              onChanged: (value) async {
                await _blockedNumbersController.setUnknownBlocked(value);
                if (!mounted) return;
                setState(() {});
              },
            ),
            SwitchListTile(
              title: Padding(
                padding: const EdgeInsets.only(left: 16.0),
                child: const Text('위험번호 자동 차단'),
              ),
              value: _blockedNumbersController.isAutoBlockDanger,
              onChanged: (value) async {
                await _blockedNumbersController.setAutoBlockDanger(value);
                if (!mounted) return;
                setState(() {});
              },
            ),
            ListTile(
              title: Padding(
                padding: const EdgeInsets.only(left: 16.0),
                child: const Text('콜폭/ㅋㅍ 차단'),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(left: 24.0),
                child: Text(
                  '현재 설정: ${_blockedNumbersController.bombCallsCount}회',
                ),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.settings),
                    onPressed: () async {
                      final controller = TextEditingController(
                        text:
                            _blockedNumbersController.bombCallsCount.toString(),
                      );
                      final count = await showDialog<int>(
                        context: context,
                        builder:
                            (context) => AlertDialog(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(5),
                              ),
                              insetPadding: const EdgeInsets.symmetric(
                                horizontal: 40,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              content: Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(
                                        labelText: '횟수',
                                        hintText: '예: 5',
                                        border: OutlineInputBorder(),
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 8,
                                        ),
                                      ),
                                      controller: controller,
                                      onSubmitted: (value) {
                                        final count = int.tryParse(value);
                                        if (count != null && count > 0) {
                                          Navigator.pop(context, count);
                                        }
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  SizedBox(
                                    height: 40,
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.black,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            5,
                                          ),
                                        ),
                                      ),
                                      onPressed: () {
                                        final count = int.tryParse(
                                          controller.text,
                                        );
                                        if (count != null && count > 0) {
                                          Navigator.pop(context, count);
                                        }
                                      },
                                      child: const Text('저장'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                      );
                      if (count != null) {
                        await _blockedNumbersController.setBombCallsCount(
                          count,
                        );
                        if (!mounted) return;
                        setState(() {});
                      }
                    },
                  ),
                  Switch(
                    value: _blockedNumbersController.isBombCallsBlocked,
                    onChanged: (value) async {
                      await _blockedNumbersController.setBombCallsBlocked(
                        value,
                      );
                      if (!mounted) return;
                      setState(() {});
                    },
                  ),
                ],
              ),
            ),
            ListTile(
              title: Padding(
                padding: const EdgeInsets.only(left: 16.0),
                child: const Text('개별 차단번호 관리'),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(left: 24.0),
                child: Text(
                  '${_blockedNumbersController.blockedNumbers.length}개의 번호가 차단되어 있습니다',
                ),
              ),
              trailing: const Icon(Icons.settings),
              onTap: () => _showBlockedNumbersDialog(context),
            ),
            ListTile(
              title: Padding(
                padding: const EdgeInsets.only(left: 16.0),
                child: const Text('차단 이력'),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(left: 24.0),
                child: Text(
                  '${_blockedNumbersController.blockedHistory.length}개의 차단 이력이 있습니다',
                ),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap:
                  () => _showBlockedHistoryDialog(
                    context,
                    _blockedNumbersController.blockedHistory,
                  ),
            ),
          ] else ...[
            // 오버레이 권한 (기본 전화앱이 아닐 때만 표시)
            SwitchListTile(
              secondary: const Icon(Icons.window),
              title: const Text('팝업으로 보기'),
              subtitle: Text(_overlayGranted ? '허용됨' : '미허용'),
              value: _overlayGranted,
              onChanged: (val) {
                _onRequestOverlayPermission();
              },
            ),
          ],

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
            onTap: () async {
              final appController = context.read<AppController>();
              await appController.cleanupOnLogout();
              await GraphQLClientManager.logout();
            },
          ),
        ],
      ),
    );
  }
}
