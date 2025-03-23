import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:get_storage/get_storage.dart';
import 'package:mobile/controllers/blocked_numbers_controller.dart';
import 'package:mobile/controllers/update_controller.dart';
import 'package:mobile/graphql/client.dart';
import 'package:mobile/graphql/user_api.dart';
import 'package:mobile/services/native_default_dialer_methods.dart';
import 'package:mobile/utils/constants.dart';
import 'package:mobile/widgets/dropdown_menus_widet.dart'; // formatDateString
import 'package:mobile/widgets/blocked_numbers_dialog.dart';
import 'package:provider/provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

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
  late String _phoneNumber; // 내 휴대폰번호
  late String _loginId; // 아이디
  late String _userName; // 이름
  late String _userRegion;
  late String _validUntil; // 만료일(문자열)

  // 업데이트 관련
  String _serverVersion = ''; // 서버에서 조회한 버전
  bool get _updateAvailable =>
      _serverVersion.isNotEmpty && _serverVersion != APP_VERSION;

  // 차단 설정 컨트롤러
  late final BlockedNumbersController _blockedNumbersController;

  // 콜폭 차단 횟수 입력 컨트롤러
  late final TextEditingController _bombCallsCountController;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    final box = GetStorage();

    // 1) 저장된 유저정보 읽어오기
    _phoneNumber = box.read<String>('myNumber') ?? '(unknown)';
    _loginId = box.read<String>('savedLoginId') ?? '(no id)';
    _userName = box.read<String>('userName') ?? '(no name)';
    _userRegion = box.read<String>('userRegion') ?? '(no region)';

    final rawValidUntil = box.read<String>(
      'userValidUntil',
    ); // 예: "1689730000" or ISO
    _validUntil = formatDateString(rawValidUntil ?? '');

    // 2) 현재 기본 전화앱인지 / 오버레이권한 인지 체크
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
      ).showSnackBar(const SnackBar(content: Text('오버레이 권한 허용됨')));
    } else {
      setState(() => _overlayGranted = false);
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

  void _showBlockedNumbersDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const BlockedNumbersDialog(),
    );
  }

  Widget _buildBlockSettingsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '차단 설정',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Column(
          children: [
            SwitchListTile(
              title: const Text('오늘 상담 차단'),
              subtitle: const Text('오늘 하루 동안 모든 전화를 차단합니다'),
              value: _blockedNumbersController.isTodayBlocked,
              onChanged: (value) async {
                await _blockedNumbersController.setTodayBlocked(value);
                setState(() {});
              },
            ),
            SwitchListTile(
              title: const Text('모르는번호 차단'),
              subtitle: const Text('전화번호부에 없는 번호를 차단합니다'),
              value: _blockedNumbersController.isUnknownBlocked,
              onChanged: (value) async {
                await _blockedNumbersController.setUnknownBlocked(value);
                setState(() {});
              },
            ),
            SwitchListTile(
              title: const Text('위험번호 자동 차단'),
              subtitle: const Text('위험번호로 등록된 번호 자동 차단'),
              value: _blockedNumbersController.isAutoBlockDanger,
              onChanged: (value) {
                // 즉시 UI 업데이트
                setState(() {
                  _blockedNumbersController.setAutoBlockDanger(value);
                });
                // 백그라운드에서 서버 업데이트
                _blockedNumbersController.setAutoBlockDanger(value).then((_) {
                  if (mounted) {
                    setState(() {});
                  }
                });
              },
            ),
            ListTile(
              title: const Text('콜폭 차단'),
              subtitle: Text(
                '현재 설정: ${_blockedNumbersController.bombCallsCount}회',
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
                        // 즉시 UI 업데이트
                        setState(() {
                          _blockedNumbersController.setBombCallsCount(count);
                        });
                        // 백그라운드에서 서버 업데이트
                        _blockedNumbersController.setBombCallsCount(count).then(
                          (_) {
                            if (mounted) {
                              setState(() {});
                            }
                          },
                        );
                      }
                    },
                  ),
                  Switch(
                    value: _blockedNumbersController.isBombCallsBlocked,
                    onChanged: (value) {
                      // 즉시 UI 업데이트
                      setState(() {
                        _blockedNumbersController.setBombCallsBlocked(value);
                      });
                      // 백그라운드에서 서버 업데이트
                      _blockedNumbersController.setBombCallsBlocked(value).then(
                        (_) {
                          if (mounted) {
                            setState(() {});
                          }
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
            ListTile(
              title: const Text('차단된 전화번호 관리'),
              onTap: () => _showBlockedNumbersDialog(context),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: AppBar(title: Text('설정'), actions: [const DropdownMenusWidget()]),
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
            onTap: GraphQLClientManager.logout,
          ),

          _buildBlockSettingsSection(),
        ],
      ),
    );
  }
}
