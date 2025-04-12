import 'dart:async';
import 'package:flutter/material.dart';
import 'dart:developer';
import 'package:mobile/services/native_methods.dart';
import 'package:provider/provider.dart';
import 'package:mobile/providers/call_state_provider.dart';
// TODO: Import constants if needed (normalizePhone etc.)

// OnCallScreen의 핵심 UI를 담당하는 위젯
class OnCallContents extends StatelessWidget {
  final String callerName;
  final String number;
  final bool connected; // 통화 연결 상태
  final VoidCallback onHangUp; // 통화 종료 콜백
  final int duration; // <<< 파라미터 추가

  const OnCallContents({
    super.key,
    required this.callerName,
    required this.number,
    required this.connected,
    required this.onHangUp,
    required this.duration, // <<< 파라미터 추가
  });

  String _formatDuration(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return "$minutes:$secs";
  }

  @override
  Widget build(BuildContext context) {
    // <<< Provider에서 상태 읽기 >>>
    final callStateProvider = context.watch<CallStateProvider>();
    final isMuted = callStateProvider.isMuted;
    final isHold = callStateProvider.isHold;
    final isSpeakerOn = callStateProvider.isSpeakerOn;

    final displayName = callerName.isNotEmpty ? callerName : number;
    final callStateText = connected ? _formatDuration(duration) : '통화 연결중...';

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
          padding: const EdgeInsets.only(bottom: 16.0),
          child: Text(
            number,
            style: const TextStyle(color: Colors.black54, fontSize: 16),
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
                context: context,
                icon: isMuted ? Icons.mic_off : Icons.mic,
                label: '음소거',
                active: isMuted,
                onTap: context.read<CallStateProvider>().toggleMute,
              ),
              _buildIconButton(
                context: context,
                icon: Icons.pause,
                label: '통화대기',
                active: isHold,
                onTap: context.read<CallStateProvider>().toggleHold,
              ),
              _buildIconButton(
                context: context,
                icon: isSpeakerOn ? Icons.volume_up : Icons.volume_down,
                label: '스피커',
                active: isSpeakerOn,
                onTap: context.read<CallStateProvider>().toggleSpeaker,
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
            onPressed: onHangUp, // <<< 외부 콜백 직접 사용
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
}
