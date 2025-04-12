// lib/screens/on_call_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:provider/provider.dart';
import 'package:mobile/controllers/contacts_controller.dart';
import 'package:mobile/models/phone_book_model.dart';
import 'package:mobile/services/native_methods.dart';
import 'package:mobile/utils/constants.dart';
import 'dart:developer';

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

  bool isMuted = false;
  bool isHold = false;
  bool isSpeakerOn = false;

  int _callDuration = 0;
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _loadContactName();

    if (widget.connected) {
      _startCallTimer();
    }
  }

  Future<void> _loadContactName() async {
    final contactsCtrl = context.read<ContactsController>();
    final normalizedNumber = normalizePhone(widget.phoneNumber);
    try {
      final contacts = await contactsCtrl.getLocalContacts();
      PhoneBookModel? contact;
      try {
        contact = contacts.firstWhere((c) => c.phoneNumber == normalizedNumber);
      } catch (e) {
        contact = null;
      }

      if (contact != null && mounted) {
        setState(() {
          _displayName = contact!.name;
        });
      }
    } catch (e) {
      log('[OnCallScreen] Error loading contact name: $e');
    }
  }

  void _startCallTimer() {
    final service = FlutterBackgroundService();
    final callerName = _displayName ?? '';

    service.invoke('startCallTimer', {
      'phoneNumber': widget.phoneNumber,
      'callerName': callerName,
    });

    _sub = service.on('updateCallUI').listen((event) {
      final elapsed = event?['elapsed'] as int? ?? 0;
      if (mounted) {
        setState(() => _callDuration = elapsed);
      }
    });
  }

  /// 통화 종료
  Future<void> _hangUp() async {
    log('[OnCallScreen] Hang up button pressed.');
    try {
      await NativeMethods.hangUpCall();
    } catch (e) {
      log('[OnCallScreen] Error calling native hangUpCall: $e');
    }

    if (widget.connected) {
      final service = FlutterBackgroundService();
      if (await service.isRunning()) {
        service.invoke('stopCallTimer');
      }
    }

    if (mounted) {
      log('[OnCallScreen] Navigating back to home after hang up.');
      Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
    }
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
