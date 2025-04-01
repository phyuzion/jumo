// lib/screens/on_call_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:provider/provider.dart';
import 'package:mobile/controllers/contacts_controller.dart';
import 'package:mobile/models/phone_book_model.dart';
import 'package:mobile/services/local_notification_service.dart';
import 'package:mobile/services/native_methods.dart';
import 'package:mobile/utils/constants.dart';

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

  // 여기서는 더이상 Timer 없음. => 백그라운드 서비스가 타이머 관리
  int _callDuration = 0;
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _loadContactName();

    final caller = _displayName ?? '';

    if (widget.connected) {
      // (1) 백그라운드 서비스로부터 타이머 업데이트 수신
      final service = FlutterBackgroundService();

      service.invoke('startCallTimer', {
        'phoneNumber': widget.phoneNumber,
        'callerName': caller,
      });
      _sub = service.on('updateCallUI').listen((event) {
        // event = { 'elapsed':..., 'phoneNumber':...}
        final elapsed = event?['elapsed'] as int? ?? 0;
        if (mounted) {
          setState(() => _callDuration = elapsed);
        }
      });
    }
  }

  Future<void> _loadContactName() async {
    final contactsController = context.read<ContactsController>();
    final contacts = contactsController.getSavedContacts();

    for (final c in contacts) {
      final phoneStr = c.phoneNumber ?? '';
      final normPhone = normalizePhone(phoneStr);
      if (normPhone == normalizePhone(widget.phoneNumber)) {
        _displayName = c.name;
        _phones = normPhone;
        if (!mounted) return;
        setState(() {});
        break;
      }
    }
  }

  /// 통화 종료
  Future<void> _hangUp() async {
    await NativeMethods.hangUpCall();
    if (widget.connected) {
      // 백그라운드 서비스 타이머 중지
      final service = FlutterBackgroundService();
      service.invoke('stopCallTimer');
    } else {
      Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
    }

    if (!mounted) return;
  }

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
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final displayNumber = widget.phoneNumber;
    final displayName = _displayName ?? widget.phoneNumber;
    final callStateText =
        widget.connected ? _formatDuration(_callDuration) : '통화 연결중...';

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 20),
            Text(
              callStateText,
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 10),
            Text(
              displayName,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 5),
            Text(displayNumber, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 20),
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
