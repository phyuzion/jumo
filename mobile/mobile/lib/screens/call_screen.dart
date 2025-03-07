// lib/screens/call_screen.dart
import 'package:flutter/material.dart';

class CallScreen extends StatelessWidget {
  const CallScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 심플하게 => 상대번호 + [스피커, 뮤트, 홀드, 종료] 등
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              '010-xxxx-xxxx',
              style: TextStyle(color: Colors.white, fontSize: 24),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildCallButton(Icons.volume_up, '스피커', () {}),
                _buildCallButton(Icons.mic_off, '뮤트', () {}),
                _buildCallButton(Icons.pause, '홀드', () {}),
              ],
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: const CircleBorder(),
                padding: const EdgeInsets.all(20),
              ),
              onPressed: () {
                // 종료
                Navigator.pop(context);
              },
              child: const Icon(Icons.call_end),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCallButton(IconData icon, String label, VoidCallback onTap) {
    return Column(
      children: [
        IconButton(
          iconSize: 36,
          color: Colors.white,
          onPressed: onTap,
          icon: Icon(icon),
        ),
        Text(label, style: const TextStyle(color: Colors.white)),
      ],
    );
  }
}
