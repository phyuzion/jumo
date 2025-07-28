import 'dart:async';
import 'package:flutter/material.dart';
import 'dart:developer';
import 'package:mobile/services/native_methods.dart';
import 'package:provider/provider.dart';
import 'package:mobile/providers/call_state_provider.dart';
import 'package:mobile/utils/constants.dart'; // normalizePhone 임포트
import 'package:mobile/widgets/call_waiting_dialog.dart'; // 추가: CallWaitingDialog 임포트
import 'package:mobile/utils/app_event_bus.dart'; // 추가: appEventBus 임포트

// OnCallScreen의 핵심 UI를 담당하는 위젯
class OnCallContents extends StatefulWidget {
  final String callerName;
  final String number;
  final bool connected; // 통화 연결 상태
  final VoidCallback onHangUp; // 통화 종료 콜백
  final int duration; // 파라미터 추가

  const OnCallContents({
    super.key,
    required this.callerName,
    required this.number,
    required this.connected,
    required this.onHangUp,
    required this.duration,
  });

  @override
  State<OnCallContents> createState() => _OnCallContentsState();
}

class _OnCallContentsState extends State<OnCallContents> {
  // 통화 중 수신 관련 상태
  bool _isShowingWaitingCallDialog = false;
  String? _ringingNumber;
  String? _ringingCallerName;
  
  // 타이머 구독
  Timer? _callCheckTimer;
  StreamSubscription? _callStateSubscription;
  
  @override
  void initState() {
    super.initState();
    
    // 타이머 시작 - 통화 상태 체크
    _startCallCheckTimer();
    
    // 이벤트 구독 로직 수정 - 타입 오류 해결
    _callStateSubscription = appEventBus.on<CallStateChangedEvent>().listen((event) {
      _checkWaitingCall();
    });
    
    log('[OnCallContents] 상태 관리 초기화 완료');
  }
  
  @override
  void dispose() {
    _callCheckTimer?.cancel();
    _callStateSubscription?.cancel();
    super.dispose();
  }
  
  // 통화 상태 체크 타이머 시작
  void _startCallCheckTimer() {
    _callCheckTimer?.cancel();
    _callCheckTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      _checkWaitingCall();
    });
    log('[OnCallContents] 통화 상태 체크 타이머 시작');
  }
  
  // 수신 통화 확인 및 다이얼로그 관리
  Future<void> _checkWaitingCall() async {
    if (!mounted) return;
    
    final callStateProvider = Provider.of<CallStateProvider>(context, listen: false);
    final ringingNumber = callStateProvider.ringingCallNumber;
    
    if (ringingNumber != null && ringingNumber.isNotEmpty) {
      if (!_isShowingWaitingCallDialog || _ringingNumber != ringingNumber) {
        // 새로운 수신 통화가 있으면 다이얼로그 표시
        _ringingNumber = ringingNumber;
        _ringingCallerName = callStateProvider.ringingCallerName;
        if (mounted) {
          setState(() {
            _isShowingWaitingCallDialog = true;
          });
        }
        log('[OnCallContents] 수신 통화 감지: $_ringingNumber, 다이얼로그 표시');
      }
    } else if (_isShowingWaitingCallDialog) {
      // 수신 통화가 없는데 다이얼로그가 표시 중이면 숨김
      if (mounted) {
        setState(() {
          _isShowingWaitingCallDialog = false;
          _ringingNumber = null;
          _ringingCallerName = null;
        });
      }
      log('[OnCallContents] 수신 통화 없음, 다이얼로그 숨김');
    }
  }

  String _formatDuration(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return "$minutes:$secs";
  }

  @override
  Widget build(BuildContext context) {
    // Provider에서 상태 읽기
    final callStateProvider = context.watch<CallStateProvider>();
    final isMuted = callStateProvider.isMuted;
    final isHold = callStateProvider.isHold;
    final isSpeakerOn = callStateProvider.isSpeakerOn;
    final holdingCallNumber = callStateProvider.holdingCallNumber;
    final holdingCallerName = callStateProvider.holdingCallerName;

    // 발신자 이름 로직 수정 - Provider에서 직접 가져옴
    final callerName = callStateProvider.callerName;
    final number = widget.number;
    final displayName = callerName.isNotEmpty ? callerName : number;
    
    // 발신자 정보 로그 기록
    if (widget.number == number) {
      log('[OnCallContents] 현재 통화 정보: 번호=$number, 이름=$callerName, 표시이름=$displayName');
    }
    
    final callStateText = widget.connected ? _formatDuration(widget.duration) : '통화 연결중...';

    // 통화 중 수신 다이얼로그 표시
    if (_isShowingWaitingCallDialog && _ringingNumber != null) {
      return CallWaitingDialog(
        phoneNumber: _ringingNumber!,
        callerName: _ringingCallerName ?? '',
        onDismiss: () {
          setState(() {
            _isShowingWaitingCallDialog = false;
          });
        },
        onAccept: () => callStateProvider.acceptWaitingCall(),
        onReject: () => callStateProvider.rejectWaitingCall(),
        onEndAndAccept: () => callStateProvider.endAndAcceptWaitingCall(),
      );
    }

    // 일반 통화 UI
    return Column(
      children: [
        // --- 상단 정보 (컴팩트하게, 폰트 크기 다시 키움) ---
        Padding(
          padding: const EdgeInsets.only(top: 16.0, bottom: 2.0),
          child: Text(
            callStateText,
            style: const TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 4.0),
          child: Text(
            displayName,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Text(
            widget.number,
            style: const TextStyle(color: Colors.black54, fontSize: 16),
          ),
        ),

        // --- 대기 중인 통화 정보 표시 ---
        if (holdingCallNumber != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
            child: Container(
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: Row(
                children: [
                  const Icon(Icons.pause, color: Colors.grey),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '대기 중인 통화',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          holdingCallerName ?? '알 수 없음',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          holdingCallNumber,
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.swap_calls, color: Colors.blue),
                    onPressed: () => callStateProvider.switchCalls(),
                    tooltip: '통화 전환',
                  ),
                ],
              ),
            ),
          ),

        const Spacer(), // 상단 정보와 하단 버튼 그룹 사이 공간
        // --- 중간 버튼 영역 (음소거, 통화대기, 스피커) ---
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 10.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildIconButton(
                context: context,
                icon: isMuted ? Icons.mic_off : Icons.mic,
                label: '음소거',
                active: isMuted,
                onTap: callStateProvider.toggleMute,
              ),
              _buildIconButton(
                context: context,
                icon: Icons.pause,
                label: '통화대기',
                active: isHold,
                onTap: callStateProvider.toggleHold,
              ),
              _buildIconButton(
                context: context,
                icon: isSpeakerOn ? Icons.volume_up : Icons.volume_down,
                label: '스피커',
                active: isSpeakerOn,
                onTap: callStateProvider.toggleSpeaker,
              ),
            ],
          ),
        ),

        // --- 하단 버튼 영역 (검색, 종료, 문자) ---
        Padding(
          padding: const EdgeInsets.only(bottom: 20.0, top: 10.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // 검색 버튼
              _buildActionButton(
                icon: Icons.search,
                label: '검색',
                color: Colors.orange,
                onTap: () => _onTapSearch(context, widget.number),
              ),
              // 통화 종료 버튼
              _buildActionButton(
                icon: Icons.call_end,
                label: '종료',
                color: Colors.red,
                onTap: widget.onHangUp,
              ),
              // 문자 버튼
              _buildActionButton(
                icon: Icons.message,
                label: '문자',
                color: Colors.blue, // 문자 색상
                onTap: () => _onTapMessage(context, widget.number),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // 검색 버튼 탭 핸들러
  void _onTapSearch(BuildContext context, String number) {
    Navigator.pushNamed(
      context,
      '/search',
      arguments: {'number': normalizePhone(number), 'isRequested': false},
    );
  }

  // 문자 보내기 핸들러
  Future<void> _onTapMessage(BuildContext context, String number) async {
    log('[CallEndedContent] Message button tapped for $number');
    await NativeMethods.openSmsApp(number);
  }

  // 아이콘 버튼 빌더
  Widget _buildIconButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    Color color = active ? Theme.of(context).primaryColor : Colors.grey;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12.0),
      child: SizedBox(
        width: 75,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 35, color: color),
            const SizedBox(height: 6),
            Text(label, style: TextStyle(fontSize: 12, color: color)),
          ],
        ),
      ),
    );
  }

  // 액션 버튼 빌더
  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 55,
            height: 55,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(color: Colors.black87, fontSize: 12),
        ),
      ],
    );
  }
}
