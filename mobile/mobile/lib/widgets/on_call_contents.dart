import 'dart:async';
import 'package:flutter/material.dart';
import 'dart:developer';
// TODO: Import NativeMethods for button actions
// TODO: Import constants if needed (normalizePhone etc.)

// OnCallScreen의 핵심 UI를 담당하는 위젯
class OnCallContents extends StatefulWidget {
  final String callerName;
  final String number;
  final bool connected; // 통화 연결 상태

  const OnCallContents({
    super.key,
    required this.callerName,
    required this.number,
    required this.connected,
  });

  @override
  State<OnCallContents> createState() => _OnCallContentsState();
}

class _OnCallContentsState extends State<OnCallContents> {
  Timer? _callTimer;
  int _callDuration = 0;

  // 버튼 상태 (임시 - 실제 상태 관리 필요)
  bool isMuted = false;
  bool isHold = false;
  bool isSpeakerOn = false;

  @override
  void initState() {
    super.initState();
    _updateTimerBasedOnState(widget.connected);
  }

  @override
  void didUpdateWidget(OnCallContents oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.connected != widget.connected) {
      _updateTimerBasedOnState(widget.connected);
    }
  }

  void _updateTimerBasedOnState(bool isConnected) {
    if (isConnected) {
      _startCallTimer();
    } else {
      _stopCallTimer();
    }
  }

  void _startCallTimer() {
    _stopCallTimer();
    _callDuration = 0;
    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && widget.connected) {
        setState(() {
          _callDuration++;
        });
      } else {
        timer.cancel();
      }
    });
    log('[OnCallContents] Call timer started.');
  }

  void _stopCallTimer() {
    _callTimer?.cancel();
    _callTimer = null;
    _callDuration = 0;
    log('[OnCallContents] Call timer stopped.');
  }

  @override
  void dispose() {
    _stopCallTimer();
    super.dispose();
  }

  String _formatDuration(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return "$minutes:$secs";
  }

  // --- 버튼 액션 핸들러 (임시) ---
  Future<void> _toggleMute() async {
    // TODO: Call NativeMethods.toggleMute(!isMuted);
    setState(() => isMuted = !isMuted);
    log('[OnCallContents] Mute toggled: $isMuted');
  }

  Future<void> _toggleHold() async {
    // TODO: Call NativeMethods.toggleHold(!isHold);
    setState(() => isHold = !isHold);
    log('[OnCallContents] Hold toggled: $isHold');
  }

  Future<void> _toggleSpeaker() async {
    // TODO: Call NativeMethods.toggleSpeaker(!isSpeakerOn);
    setState(() => isSpeakerOn = !isSpeakerOn);
    log('[OnCallContents] Speaker toggled: $isSpeakerOn');
  }

  Future<void> _hangUp() async {
    log('[OnCallContents] Hang up tapped');
    // TODO: Call NativeMethods.hangUpCall();
    // TODO: Notify state change (e.g., call ended)
    _stopCallTimer(); // 타이머 중지
    // TODO: Close popup (via callback?)
  }
  // --- 버튼 액션 핸들러 끝 ---

  @override
  Widget build(BuildContext context) {
    final displayName =
        widget.callerName.isNotEmpty ? widget.callerName : widget.number;
    final callStateText =
        widget.connected ? _formatDuration(_callDuration) : '통화 연결중...';

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
          padding: const EdgeInsets.only(bottom: 16.0),
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

        // --- 중간 버튼 영역 (Card 제거) ---
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 40.0,
            vertical: 10.0,
          ), // 패딩 조정
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildIconButton(
                icon: isMuted ? Icons.mic_off : Icons.mic,
                label: '음소거', // 라벨 유지 (작게)
                active: isMuted,
                onTap: _toggleMute,
              ),
              _buildIconButton(
                icon: Icons.pause,
                label: '통화대기', // 라벨 유지 (작게)
                active: isHold,
                onTap: _toggleHold,
              ),
              _buildIconButton(
                icon:
                    isSpeakerOn ? Icons.volume_up : Icons.volume_down, // 아이콘 변경
                label: '스피커', // 라벨 유지 (작게)
                active: isSpeakerOn,
                onTap: _toggleSpeaker,
              ),
            ],
          ),
        ),

        const Spacer(), // 하단 종료 버튼 위 공간
        // --- 하단 종료 버튼 ---
        Padding(
          padding: const EdgeInsets.only(bottom: 20.0, top: 10.0),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: const CircleBorder(),
              padding: const EdgeInsets.all(18), // 크기 약간 줄임
            ),
            onPressed: _hangUp,
            child: const Icon(
              Icons.call_end,
              color: Colors.white,
              size: 30,
            ), // 크기 약간 줄임
          ),
        ),
      ],
    );
  }

  // 아이콘 버튼 빌더 (OnCallScreen 스타일 참고, 라벨 포함)
  Widget _buildIconButton({
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
}
