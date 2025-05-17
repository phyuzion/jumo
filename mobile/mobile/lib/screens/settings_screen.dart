import 'package:flutter/material.dart';
import 'package:mobile/controllers/blocked_numbers_controller.dart';
import 'package:mobile/controllers/update_controller.dart';
import 'package:mobile/graphql/client.dart';
import 'package:mobile/graphql/user_api.dart';
import 'package:mobile/models/blocked_history.dart';
import 'package:mobile/models/blocked_number.dart';
import 'package:mobile/repositories/auth_repository.dart';
import 'package:mobile/services/native_default_dialer_methods.dart';
import 'package:mobile/utils/constants.dart';
import 'package:mobile/widgets/dropdown_menus_widet.dart'; // formatDateString
import 'package:mobile/widgets/blocked_numbers_dialog.dart';
import 'package:mobile/widgets/blocked_history_dialog.dart';
import 'package:provider/provider.dart';
import 'package:mobile/controllers/app_controller.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:developer';
//import 'package:system_alert_window/system_alert_window.dart';

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

  /* overlay removed
  /// 오버레이 권한 여부
  bool _overlayGranted = false;
  */

  /// 유저 정보
  String _phoneNumber = '(정보 로딩중)';
  String _loginId = '(정보 로딩중)';
  String _userName = '(정보 로딩중)';
  String _userRegion = '(정보 로딩중)';
  String _validUntil = '';
  String _rawValidUntil = ''; // <<< 만료일 원본 문자열 저장
  int? _daysUntilExpiry; // <<< 남은 일수 (null 가능)
  String _userGrade = '일반';

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

    // initState 이후 프레임에서 비동기 작업 수행
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeSettings();
    });

    // 3) 차단 설정 컨트롤러 초기화
    _blockedNumbersController = context.read<BlockedNumbersController>();

    // 4) 콜폭 차단 횟수 입력 컨트롤러 초기화
    _bombCallsCountController = TextEditingController();
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

  /// (B-1) [업데이트] 버튼 탭 시 동작 (기존 방식: 자동 다운로드 및 설치 시도)
  Future<void> _onTapUpdateInstall() async {
    final updateCtrl = UpdateController();
    try {
      await updateCtrl.downloadAndInstallApk();
    } catch (e) {
      log('Error during download/install: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('업데이트 중 오류 발생: $e')));
    }
  }

  /// (B-2) [직접 다운로드] 버튼 탭 시 동작 (URL 실행)
  Future<void> _onTapDirectDownload() async {
    final Uri apkUrl = Uri.parse(
      'https://jumo-vs8e.onrender.com/download/app.apk',
    );

    try {
      if (await canLaunchUrl(apkUrl)) {
        await launchUrl(apkUrl, mode: LaunchMode.externalApplication);
      } else {
        log('Could not launch $apkUrl');
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('다운로드 링크를 열 수 없습니다.')));
      }
    } catch (e) {
      log('Error launching URL: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('링크를 여는 중 오류 발생: $e')));
    }
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

  // 설정 화면 초기화 (비동기 작업 포함)
  Future<void> _initializeSettings() async {
    // 병렬로 실행 가능한 작업들
    final List<Future> futures = [
      _loadUserInfo(), // 사용자 정보 로드
      _checkStatus(), // 기본 전화앱, 권한 등 상태 확인
      _checkVersionManually(), // 버전 체크
    ];
    // 모든 작업이 완료될 때까지 기다림
    await Future.wait(futures);

    // <<< 남은 일수 계산 로직 호출 >>>
    _calculateDaysUntilExpiry();

    // 모든 데이터 로드 후 콜폭 차단 횟수 컨트롤러 텍스트 설정
    if (mounted) {
      _bombCallsCountController.text =
          _blockedNumbersController.bombCallsCount.toString();
      // 최종 상태 업데이트
      setState(() {});
    }
  }

  // Hive에서 사용자 정보 로드 (AuthRepository 사용)
  Future<void> _loadUserInfo() async {
    final authRepository = context.read<AuthRepository>();

    final results = await Future.wait([
      authRepository.getMyNumber(),
      authRepository.getSavedCredentials(),
      authRepository.getUserName(),
      authRepository.getUserRegion(),
      authRepository.getUserGrade(),
      authRepository.getUserValidUntil(),
    ]);

    if (!mounted) return;

    _phoneNumber = (results[0] as String?) ?? '(정보 없음)';
    final credentials = results[1] as Map<String, String?>;
    _loginId = credentials['savedLoginId'] ?? '(정보 없음)';
    _userName = (results[2] as String?) ?? '(정보 없음)';
    _userRegion = (results[3] as String?) ?? '(정보 없음)';
    _userGrade = (results[4] as String?) ?? '일반';
    _rawValidUntil = (results[5] as String?) ?? ''; // <<< 원본 문자열 저장
    _validUntil = formatDateString(_rawValidUntil); // 포맷된 문자열 저장
  }

  // <<< 남은 일수 계산 함수 수정 >>>
  void _calculateDaysUntilExpiry() {
    if (_rawValidUntil.isEmpty) {
      _daysUntilExpiry = null;
      return;
    }
    try {
      // <<< 수정: int.tryParse 및 fromMillisecondsSinceEpoch 사용 >>>
      final epochMs = int.tryParse(_rawValidUntil);
      if (epochMs == null) {
        throw FormatException('Cannot parse epoch milliseconds from string');
      }
      // UTC로 저장되어 있다고 가정하고 로컬 시간대로 변환
      final expiryDate =
          DateTime.fromMillisecondsSinceEpoch(epochMs, isUtc: true).toLocal();

      final today = DateTime.now();
      final expiryDay = DateTime(
        expiryDate.year,
        expiryDate.month,
        expiryDate.day,
      );
      final todayDay = DateTime(today.year, today.month, today.day);
      log(
        '[_SettingsScreenState][Expiry] Expiry Day: $expiryDay, Today Day: $todayDay',
      );

      final difference = expiryDay.difference(todayDay).inDays;
      _daysUntilExpiry = difference;
      log(
        '[_SettingsScreenState][Expiry] Calculated days until expiry: $_daysUntilExpiry',
      );
    } catch (e) {
      log('[_SettingsScreenState][Expiry] Error processing expiry date: $e');
      _daysUntilExpiry = null;
    }
  }

  Future<void> _checkStatus() async {
    // checkStatus 시작 시 로딩 상태 설정은 _initializeSettings에서 이미 처리
    // setState(() => _checking = true); // 제거

    // (A) 기본 전화앱 여부
    final defDialer = await NativeDefaultDialerMethods.isDefaultDialer();

    if (!mounted) return;
    // 로딩 상태 해제 및 UI 업데이트는 _initializeSettings 마지막에 한 번만
    // setState(() {
    //   _checking = false;
    //   _isDefaultDialer = defDialer;
    // });
    _isDefaultDialer = defDialer; // 변수 값만 업데이트
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

  /* overlay removed
  /// 오버레이 권한
  Future<void> _onRequestOverlayPermission() async {
    final result = await SystemAlertWindow.requestPermissions(
      prefMode: SystemWindowPrefMode.OVERLAY,
    );
    // result == true 면 성공
    if (!mounted) return;
    if (result == true) {
      setState(() => _overlayGranted = true);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('팝업 권한 허용됨')));
    } else {
      setState(() => _overlayGranted = false);
      // (선택적) 사용자 안내 메시지
      if (mounted) {
        // 스낵바 사용 전 mounted 확인
        ScaffoldMessenger.of(context).showSnackBar(
          // 문자열 리터럴을 큰따옴표로 수정
          const SnackBar(
            content: Text("'다른 앱 위에 표시' 권한 설정 화면으로 이동합니다. 권한을 허용해주세요."),
          ),
        );
      }
    }
  }
*/

  /// 비밀번호 변경
  Future<void> _onChangePassword() async {
    final oldPwCtrl = TextEditingController();
    final newPwCtrl = TextEditingController();
    // <<< 상태 관리를 위해 변수 추가 >>>
    bool showOldPassword = false;
    bool showNewPassword = false;

    final result = await showDialog<bool>(
      context: context,
      // <<< StatefulBuilder 사용 >>>
      builder:
          (dialogContext) => StatefulBuilder(
            builder: (context, setStateDialog) {
              return AlertDialog(
                title: const Text('비밀번호 변경'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: oldPwCtrl,
                      decoration: InputDecoration(
                        labelText: '기존 비번',
                        // <<< 미리보기 아이콘 추가 >>>
                        suffixIcon: IconButton(
                          icon: Icon(
                            showOldPassword
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                          onPressed: () {
                            setStateDialog(() {
                              showOldPassword = !showOldPassword;
                            });
                          },
                        ),
                      ),
                      obscureText: !showOldPassword, // <<< 상태 반영
                    ),
                    TextField(
                      controller: newPwCtrl,
                      decoration: InputDecoration(
                        labelText: '새 비번',
                        // <<< 미리보기 아이콘 추가 >>>
                        suffixIcon: IconButton(
                          icon: Icon(
                            showNewPassword
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                          onPressed: () {
                            setStateDialog(() {
                              showNewPassword = !showNewPassword;
                            });
                          },
                        ),
                      ),
                      obscureText: !showNewPassword, // <<< 상태 반영
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed:
                        () => Navigator.pop(
                          dialogContext,
                          false,
                        ), // <<< context 변경
                    child: const Text('취소'),
                  ),
                  TextButton(
                    onPressed:
                        () => Navigator.pop(
                          dialogContext,
                          true,
                        ), // <<< context 변경
                    child: const Text('확인'),
                  ),
                ],
              );
            },
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

  @override
  Widget build(BuildContext context) {
    // <<< 만료 알림 위젯 생성 로직 >>>
    Widget? expiryWarningWidget;
    if (_daysUntilExpiry != null) {
      String warningMessage = '';
      if (_daysUntilExpiry! < 0) {
        warningMessage = '계정이 만료되었습니다.';
      } else if (_daysUntilExpiry == 0) {
        warningMessage = '계정 만료일이 오늘입니다.';
      } else if (_daysUntilExpiry! <= 3) {
        warningMessage = '계정 만료일이 ${_daysUntilExpiry}일 남았습니다.';
      }

      if (warningMessage.isNotEmpty) {
        expiryWarningWidget = Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: Colors.red,
          child: Text(
            warningMessage,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        );
      }
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
          // <<< 만료 알림 위젯 추가 (null 아닐 경우) >>>
          if (expiryWarningWidget != null) expiryWarningWidget,

          // (1) 업데이트 알림 ListTile 수정
          if (_updateAvailable)
            ListTile(
              // isThreeLine: true, // subtitle이 여러 줄이 될 수 있음을 명시 (선택적)
              title: const Text(
                '새로운 버전 설치 가능!',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
              subtitle: Column(
                // <<< subtitle에 Column 사용
                crossAxisAlignment: CrossAxisAlignment.start, // 텍스트 왼쪽 정렬
                children: [
                  Text(
                    // <<< 기존 subtitle 텍스트
                    '서버 버전: $_serverVersion / 현재 버전: $APP_VERSION\n보안 이슈로 설치가 안될 경우 [직접 다운로드]로 설치하세요.',
                  ),
                  const SizedBox(height: 8), // 텍스트와 버튼 사이 간격
                  Row(
                    // <<< 버튼들을 담을 Row
                    mainAxisAlignment: MainAxisAlignment.end, // 버튼들을 오른쪽으로 정렬
                    children: [
                      ElevatedButton(
                        // <<< 업데이트 버튼
                        onPressed: _onTapUpdateInstall,
                        // 버튼 크기 조절 (선택적)
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          textStyle: TextStyle(fontSize: 13),
                        ),
                        child: const Text('업데이트'),
                      ),
                      const SizedBox(width: 8), // 버튼 사이 간격
                      TextButton(
                        // <<< 직접 다운로드 버튼
                        onPressed: _onTapDirectDownload,
                        // 버튼 크기 조절 (선택적)
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          textStyle: TextStyle(fontSize: 13),
                        ),
                        child: const Text('직접 다운로드'),
                      ),
                    ],
                  ),
                ],
              ),
              // trailing 제거
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
                child: const Text('오늘 전화문의 차단'),
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
                child: const Text('저장 안된 번호 차단'),
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
              subtitle: Padding(
                padding: const EdgeInsets.only(left: 24.0),
                child: Text('회원 3명 이상 "위험" 등록시 자동 차단'),
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
                                        hintText: '예: 3',
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
                      if (value == true) {
                        // 스위치를 켤 때
                        // 현재 설정된 콜폭 횟수가 0 (기본값으로 간주)이라면 3으로 설정
                        // 만약 bombCallsCount의 "미설정" 기본값이 0이 아니라면 해당 값으로 조건을 변경해야 합니다.
                        if (_blockedNumbersController.bombCallsCount == 0) {
                          await _blockedNumbersController.setBombCallsCount(3);
                          // 화면에 즉시 반영을 위해 bombCallsCountController의 text도 업데이트 (선택적)
                          // 이 값은 다음 setState 호출 시 어차피 컨트롤러 값으로 업데이트됨
                          // _bombCallsCountController.text = '3';
                        }
                      }
                      // 스위치 상태 자체는 항상 업데이트
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
                child: const Text('시작번호/지정번호 차단'),
              ),
              subtitle: FutureBuilder<List<BlockedNumber>>(
                future: _blockedNumbersController.blockedNumbers,
                builder: (context, snapshot) {
                  String countText = '...'; // 로딩 또는 에러 시 표시할 텍스트
                  if (snapshot.connectionState == ConnectionState.done &&
                      snapshot.hasData) {
                    countText = '${snapshot.data!.length}개의 번호가 차단되어 있습니다';
                  } else if (snapshot.hasError) {
                    countText = '개수 로딩 오류';
                  }
                  return Padding(
                    padding: const EdgeInsets.only(left: 24.0),
                    // <<< Column 위젯으로 변경 >>>
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ex) 010-12**-****, 070-***-****',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        Text(countText),
                      ],
                    ),
                  );
                },
              ),
              trailing: const Icon(Icons.settings),
              onTap: () => _showBlockedNumbersDialog(context),
            ),
            ListTile(
              title: Padding(
                padding: const EdgeInsets.only(left: 16.0),
                child: const Text('차단 이력'),
              ),
              subtitle: FutureBuilder<List<BlockedHistory>>(
                future: _blockedNumbersController.blockedHistory,
                builder: (context, snapshot) {
                  String text = '...'; // 로딩 또는 에러 시 표시할 텍스트
                  if (snapshot.connectionState == ConnectionState.done &&
                      snapshot.hasData) {
                    text = '${snapshot.data!.length}개의 차단 이력이 있습니다';
                  } else if (snapshot.hasError) {
                    text = '개수 로딩 오류';
                  }
                  return Padding(
                    padding: const EdgeInsets.only(left: 24.0),
                    child: Text(text),
                  );
                },
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                // <<< async 추가: blockedHistory를 기다려야 함 >>>
                // FutureBuilder는 데이터를 표시만 하므로 실제 데이터를 가져와 전달
                try {
                  final history =
                      await _blockedNumbersController.blockedHistory;
                  if (mounted) {
                    _showBlockedHistoryDialog(context, history);
                  }
                } catch (e) {
                  log('Error fetching history for dialog: $e');
                }
              },
            ),
          ],

          /*overlay removed
          else ...[
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
          */
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
              // 로그아웃 시 정리 작업 (기존 로직 복원)
              final appController = context.read<AppController>();
              await appController.cleanupOnLogout();
              // GraphQLClientManager 로그아웃 호출 (기존 방식 복원)
              await GraphQLClientManager.logout();
              if (!mounted) return;
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/login',
                (route) => false,
              );
            },
          ),
        ],
      ),
    );
  }
}
