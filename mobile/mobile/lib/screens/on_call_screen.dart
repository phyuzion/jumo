import 'package:flutter/material.dart';
import '../services/native_methods.dart';
import '../controllers/contacts_controller.dart';

class OnCallScreen extends StatefulWidget {
  const OnCallScreen({super.key});

  @override
  State<OnCallScreen> createState() => _OnCallScreenState();
}

class _OnCallScreenState extends State<OnCallScreen> {
  String phoneNumber = '';
  String? contactName;
  bool isMuted = false;
  bool isHold = false;
  bool isSpeakerOn = false;

  @override
  void initState() {
    super.initState();
    // initState 내에서 ModalRoute arguments 가져오기
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is String) {
        phoneNumber = args;
        _loadContactName(args);
      } else {
        phoneNumber = '';
      }
      setState(() {});
    });
  }

  Future<void> _loadContactName(String number) async {
    final contactsController = ContactsController();
    final contacts = contactsController.getSavedContacts();
    for (final c in contacts) {
      final ph = c['phones'] as String? ?? '';
      if (ph.contains(number)) {
        setState(() {
          contactName = c['name'] as String?;
        });
        return;
      }
    }
    // 없으면 그대로
  }

  Future<void> _toggleMute() async {
    final newVal = !isMuted;
    await NativeMethods.toggleMute(newVal);
    setState(() => isMuted = newVal);
  }

  Future<void> _toggleHold() async {
    final newVal = !isHold;
    await NativeMethods.toggleHold(newVal);
    setState(() => isHold = newVal);
  }

  Future<void> _toggleSpeaker() async {
    final newVal = !isSpeakerOn;
    // TODO: 실제 NativeMethods.toggleSpeaker(newVal) 가 있다면 호출
    // 여기서는 UI만
    setState(() => isSpeakerOn = newVal);
  }

  Future<void> _hangUp() async {
    await NativeMethods.hangUpCall();
    // 통화 종료 -> phone_state_controller => CALL_ENDED => ...
    // 여기서는 화면만 닫거나, Navigator.pop(context)
    if (!mounted) return;
    //Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final displayName = contactName ?? phoneNumber;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 20),
            const Text(
              '통화 연결중...',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 10),
            Text(
              displayName,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 30),

            // 중앙 Card (뮤트, 홀드, 스피커)
            Card(
              elevation: 4, // 그림자
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              margin: const EdgeInsets.symmetric(horizontal: 40),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 24,
                  runSpacing: 24,
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

            // 하단 종료 버튼
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
