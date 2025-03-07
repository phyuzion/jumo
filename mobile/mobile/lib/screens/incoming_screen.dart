// lib/screens/incoming_screen.dart
import 'package:flutter/material.dart';

class IncomingScreen extends StatelessWidget {
  const IncomingScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 배경 블랙, 가운데 리스트(전화번호부 검색결과 등)
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 30),
            const Text(
              '수신 전화',
              style: TextStyle(color: Colors.white, fontSize: 24),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Container(
                color: Colors.white24,
                child: ListView.builder(
                  itemCount: 10, // demo
                  itemBuilder: (ctx, i) {
                    return ListTile(
                      title: Text(
                        '연락처$i',
                        style: const TextStyle(color: Colors.white),
                      ),
                      subtitle: const Text(
                        '010-xxxx-xxxx',
                        style: TextStyle(color: Colors.white70),
                      ),
                    );
                  },
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  iconSize: 60,
                  icon: const Icon(Icons.call_end),
                  color: Colors.red,
                  onPressed: () {
                    // 거절
                    Navigator.pop(context);
                  },
                ),
                IconButton(
                  iconSize: 60,
                  icon: const Icon(Icons.call),
                  color: Colors.green,
                  onPressed: () {
                    // 수락 -> CallScreen
                    Navigator.pushReplacementNamed(context, '/callScreen');
                  },
                ),
              ],
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
