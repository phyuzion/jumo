import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:mobile/controllers/contacts_controller.dart';
import 'package:mobile/models/phone_book_model.dart';
import 'package:mobile/utils/constants.dart';
import 'package:mobile/services/native_methods.dart';

class OnCallScreen extends StatefulWidget {
  final String phoneNumber;
  final bool connected;

  const OnCallScreen({
    super.key,
    required this.phoneNumber,
    required this.connected,
  });

  @override
  State<OnCallScreen> createState() => _OnCallScreenState();
}

class _OnCallScreenState extends State<OnCallScreen> {
  String? _displayName;
  String? _phones;

  bool isMuted = false;
  bool isHold = false;
  bool isSpeakerOn = false;

  Timer? _timer; // 매 초마다 동작할 타이머
  int _callDuration = 0; // 통화 지속 시간 (초)

  @override
  void initState() {
    super.initState();

    // 1) 통화 연결 상태면 타이머 시작
    if (widget.connected) {
      _startTimer();
    }

    // 2) 주소록에서 번호 매칭 후 이름/번호 가져오기
    _loadContactName();
  }

  /// 주소록(이미 저장)에서 widget.phoneNumber 와 일치하는 contact 찾기
  Future<void> _loadContactName() async {
    final contactsController = context.read<ContactsController>();
    final contacts = contactsController.getSavedContacts();

    for (final c in contacts) {
      final phoneStr = c.phoneNumber ?? '';
      final normPhone = normalizePhone(phoneStr);

      if (normPhone == normalizePhone(widget.phoneNumber)) {
        setState(() {
          _displayName = c.name;
          _phones = normPhone;
        });
        break;
      }
    }
  }

  /// 통화 타이머 시작
  void _startTimer() {
    _timer?.cancel(); // 혹시 몰라 기존 타이머 있으면 취소
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _callDuration++;
      });
    });
  }

  /// 통화 타이머 중지
  void _stopTimer() {
    _timer?.cancel();
  }

  /// 통화 종료
  Future<void> _hangUp() async {
    await NativeMethods.hangUpCall();
    _stopTimer();
    if (!mounted) return;

    // 여기서 팝 or 다른 화면으로 이동 처리 가능
    // Navigator.pop(context);
  }

  /// 통화시간 (초)을 MM:SS 포맷으로 반환
  String _formatDuration(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return "$minutes:$secs";
  }

  /// (1) 뮤트
  Future<void> _toggleMute() async {
    final newVal = !isMuted;
    await NativeMethods.toggleMute(newVal);
    setState(() => isMuted = newVal);
  }

  /// (2) 홀드
  Future<void> _toggleHold() async {
    final newVal = !isHold;
    await NativeMethods.toggleHold(newVal);
    setState(() => isHold = newVal);
  }

  /// (3) 스피커
  Future<void> _toggleSpeaker() async {
    final newVal = !isSpeakerOn;
    await NativeMethods.toggleSpeaker(newVal);
    setState(() => isSpeakerOn = newVal);
  }

  @override
  void dispose() {
    // 화면 해제될 때 타이머 중지
    _stopTimer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 표시할 이름이 있으면 이름, 아니면 원본 전화번호

    final displayNumber = widget.phoneNumber;
    final displayName = _displayName ?? widget.phoneNumber;

    // connected=false면 "통화 연결중...", true면 "00:02" 같은 타이머
    final callStateText =
        widget.connected ? _formatDuration(_callDuration) : '통화 연결중...';

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 20),
            // 통화 상태 (연결중 or 타이머)
            Text(
              callStateText,
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 10),

            // 상대방 이름/번호
            Text(
              displayName,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              displayNumber,
              style: const TextStyle(color: Colors.black, fontSize: 16),
            ),
            const SizedBox(height: 20),
            // 중앙 Card (뮤트, 홀드, 스피커)
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              margin: const EdgeInsets.symmetric(horizontal: 40),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildIconButton(
                      icon: isMuted ? Icons.mic_off : Icons.mic,
                      label: '뮤트',
                      active: isMuted,
                      onTap: _toggleMute,
                    ),
                    _buildIconButton(
                      icon: Icons.pause,
                      label: '홀드',
                      active: isHold,
                      onTap: _toggleHold,
                    ),
                    _buildIconButton(
                      icon: Icons.volume_up,
                      label: '스피커',
                      active: isSpeakerOn,
                      onTap: _toggleSpeaker,
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(),

            // 하단 '통화 종료' 버튼
            Padding(
              padding: const EdgeInsets.only(bottom: 40),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  shape: const CircleBorder(),
                  padding: const EdgeInsets.all(20),
                ),
                onPressed: _hangUp,
                child: const Icon(
                  Icons.call_end,
                  color: Colors.white,
                  size: 32,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 아이콘 버튼 공통 위젯
  Widget _buildIconButton({
    required IconData icon,
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        width: 70,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 32, color: active ? Colors.blue : Colors.grey),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: active ? Colors.blue : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
