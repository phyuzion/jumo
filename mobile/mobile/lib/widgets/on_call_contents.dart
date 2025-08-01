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
  StreamSubscription? _callWaitingSubscription; // 대기 통화 이벤트 구독 추가
  
  @override
  void initState() {
    super.initState();
    
    // 타이머 시작 - 통화 상태 체크
    _startCallCheckTimer();
    
    // 이벤트 구독 로직 수정 - 타입 오류 해결
    _callStateSubscription = appEventBus.on<CallStateChangedEvent>().listen((event) {
      // 상태 변경 이벤트 발생 시 즉시 체크
      _checkWaitingCall();
    });
    
    // 대기 통화 이벤트 구독
    _callWaitingSubscription = appEventBus.on<CallWaitingEvent>().listen(_handleWaitingCall);
    
    log('[OnCallContents] 상태 관리 초기화 완료');
  }
  
  @override
  void dispose() {
    _callCheckTimer?.cancel();
    _callStateSubscription?.cancel();
    _callWaitingSubscription?.cancel(); // 구독 취소 추가
    super.dispose();
  }
  
  // 대기 통화 이벤트 처리 (직접적인 대기 통화 이벤트 수신 로직)
  Future<void> _handleWaitingCall(CallWaitingEvent event) async {
    log('[OnCallContents] 대기 통화 이벤트 수신: 활성=${event.activeNumber}, 대기=${event.waitingNumber}');
    
    if (!mounted) return;
    
    try {
      // 현재 활성 통화인지 확인
      final provider = Provider.of<CallStateProvider>(context, listen: false);
      final currentState = provider.callState;
      
      if (currentState != CallState.active) {
        log('[OnCallContents] 현재 활성 통화 상태가 아니므로 대기 통화 이벤트 무시: $currentState');
        return;
      }
      
      // 대기 번호 정보 설정
      _ringingNumber = event.waitingNumber;
      _ringingCallerName = provider.ringingCallerName;
      
      // 기존 타이머는 잠시 취소 (중복 처리 방지)
      _callCheckTimer?.cancel();
      
      // 즉시 다이얼로그 표시 (타이머나 추가 확인 없이)
      log('[OnCallContents] 대기 통화 다이얼로그 즉시 표시 (이벤트 기반)');
      
      // 기존에 대기 통화 다이얼로그가 표시 중인지 확인
      if (_isShowingWaitingCallDialog) {
        // 이미 표시 중이면 새로운 번호로 업데이트만
        if (_ringingNumber != event.waitingNumber) {
          log('[OnCallContents] 기존 다이얼로그 갱신: ${_ringingNumber} -> ${event.waitingNumber}');
          setState(() {
            _ringingNumber = event.waitingNumber;
            _ringingCallerName = provider.ringingCallerName;
          });
        }
      } else {
        // 새로 표시 - 상태 즉시 업데이트
        setState(() {
          _isShowingWaitingCallDialog = true;
        });
      }
      
      // 타이머 재시작
      _startCallCheckTimer();
    } catch (e) {
      // 위젯이 dispose 되었거나 다른 예외가 발생한 경우
      log('[OnCallContents] 대기 통화 이벤트 처리 중 오류 발생: $e');
      // 타이머 재시작 시도 (오류 발생해도 타이머는 동작하도록)
      _startCallCheckTimer();
    }
  }
  // 통화 상태 체크 타이머 시작 (최적화)
  void _startCallCheckTimer() {
    _callCheckTimer?.cancel();
    // 간격을 늈려 UI 영향 최소화 (1초 간격)
    _callCheckTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _checkWaitingCall();
    });
    log('[OnCallContents] 통화 상태 체크 타이머 시작 (1초 간격)');
  }
  
  // 수신 통화 확인 및 다이얼로그 관리 (타이머 기반 체크)
  Future<void> _checkWaitingCall() async {
    // 위젯이 화면에 표시되지 않으면 즉시 종료
    if (!mounted) return;
    
    try {
      final callStateProvider = Provider.of<CallStateProvider>(context, listen: false);
      final ringingNumber = callStateProvider.ringingCallNumber;
      final currentState = callStateProvider.callState;
      
      // 현재 상태가 활성 통화가 아닌 경우 처리하지 않음 (상태 전환 중에는 작업 안함)
      if (currentState != CallState.active) {
        // 통화가 끝났거나 상태 전환 중인데 대기 통화 다이얼로그가 표시 중이면 숨김
        if (_isShowingWaitingCallDialog) {
          setState(() {
            _isShowingWaitingCallDialog = false;
            _ringingNumber = null;
            _ringingCallerName = null;
          });
          log('[OnCallContents] 활성 통화 종료 감지, 대기 통화 다이얼로그 숨김');
        }
        return;
      }
      
      // 이미 이벤트 기반으로 처리되었는지 확인 (중복 처리 방지)
      if (_isShowingWaitingCallDialog && _ringingNumber == ringingNumber && ringingNumber != null) {
        // 이미 동일한 번호로 다이얼로그가 표시 중이면 추가 처리 생략
        return;
      }
      
      // CallState.active 상태이고 ringingNumber가 있으면 무조건 다이얼로그 표시
      final bool shouldShowDialog = currentState == CallState.active && 
                                   ringingNumber != null && 
                                   ringingNumber.isNotEmpty;
      
      // 대기 통화 다이얼로그가 표시되어야 하는 경우
      if (shouldShowDialog) {
        if (!_isShowingWaitingCallDialog || _ringingNumber != ringingNumber) {
          // 새로운 수신 통화가 있으면 다이얼로그 표시
          _ringingNumber = ringingNumber;
          _ringingCallerName = callStateProvider.ringingCallerName;
          
          // 다이얼로그 표시 상태 변경 (setState 호출 전에 log 기록)
          log('[OnCallContents] 타이머 체크: 수신 통화 감지: $_ringingNumber, 다이얼로그 표시');
          
          // 상태 즉시 업데이트
          setState(() {
            _isShowingWaitingCallDialog = true;
          });
        }
      } 
      // 대기 통화 다이얼로그가 표시 중이지만 표시되지 않아야 하는 경우
      else if (_isShowingWaitingCallDialog) {
        // 수신 통화가 없어졌거나 달라졌으면 다이얼로그 숨김
        setState(() {
          _isShowingWaitingCallDialog = false;
          _ringingNumber = null;
          _ringingCallerName = null;
        });
        log('[OnCallContents] 대기 통화 종료 감지, 다이얼로그 숨김');
      }
    } catch (e) {
      // 위젯이 dispose 되었거나 다른 예외가 발생한 경우
      log('[OnCallContents] 통화 상태 체크 중 오류 발생: $e');
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
    final currentCallState = callStateProvider.callState;

    // 활성 통화 중에만 화면 표시
    if (currentCallState != CallState.active) {
      log('[OnCallContents] 활성 통화 상태가 아님: $currentCallState, UI를 표시하지 않음');
      return const SizedBox.shrink(); // 빈 위젯 반환하여 화면 표시하지 않음
    }

    // 발신자 이름 로직 수정 - Provider에서 직접 가져옴
    final callerName = callStateProvider.callerName;
    final number = widget.number;
    final displayName = callerName.isNotEmpty ? callerName : number;
    
    // 발신자 정보 로그 기록 (로그 빈도 줄임)
    if (widget.number == number && number.isNotEmpty) {
      // log('[OnCallContents] 현재 통화 정보: 번호=$number, 이름=$callerName, 표시이름=$displayName');
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
