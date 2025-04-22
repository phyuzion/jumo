import 'dart:async';
import 'package:flutter/material.dart';
import 'dart:developer';
import 'package:mobile/services/native_methods.dart';
import 'package:provider/provider.dart';
import 'package:mobile/providers/call_state_provider.dart';
import 'package:mobile/utils/constants.dart'; // <<< normalizePhone 임포트
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
                onTap: () => _onTapSearch(context, number),
              ),
              // 통화 종료 버튼
              _buildActionButton(
                icon: Icons.call_end,
                label: '종료',
                color: Colors.red,
                onTap: onHangUp,
              ),
              // 문자 버튼
              _buildActionButton(
                icon: Icons.message,
                label: '문자',
                color: Colors.blue, // 문자 색상

                onTap: () => _onTapMessage(context, number),
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
    // TODO: Close popup after navigation? (Notify HomeScreen)
  }

  // <<< 문자 보내기 핸들러 추가 >>>
  Future<void> _onTapMessage(BuildContext context, String number) async {
    log('[CallEndedContent] Message button tapped for $number');
    await NativeMethods.openSmsApp(number);
    // TODO: Close popup?
  }

  // 아이콘 버튼 빌더 (CallEndedContent 스타일 참고, 활성/비활성 상태 추가)
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

  // 액션 버튼 빌더 (call_ended_content.dart 스타일 - 원형 배경)
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

// <<< 아래 함수는 utils/constants.dart 에 정의되어 있다면 제거해도 됩니다 >>>
// String normalizePhone(String phone) {
//   // TODO: Implement actual phone normalization logic if needed
//   return phone.replaceAll(RegExp(r'[^0-9+]'), '');
// }
