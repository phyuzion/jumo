import 'package:flutter/material.dart';

class CallEndedScreen extends StatelessWidget {
  const CallEndedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // 예: arguments 받기 (이름, 번호)
    // final args = ModalRoute.of(context)?.settings.arguments;
    // String name = '';
    // String number = '';
    // if(args is Map<String, String>) {
    //   name = args['name'] ?? '';
    //   number = args['number'] ?? '';
    // }

    // 여기서는 예시로 고정
    final name = '홍길동';
    final number = '010-1234-5678';

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 100),
            // 상단: 이름 / 번호
            Text(
              name,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              number,
              style: const TextStyle(color: Colors.black, fontSize: 16),
            ),
            const SizedBox(height: 20),
            // "통화가 종료되었습니다" 등 안내 문구
            const Text(
              '통화가 종료되었습니다.',
              style: TextStyle(fontSize: 18, color: Colors.red),
            ),

            const Spacer(),

            // 하단 아이콘들(검색, 편집, 신고)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildActionButton(
                  icon: Icons.search,
                  color: Colors.orange,
                  label: '검색',
                  onTap: () {
                    // TODO
                  },
                ),
                _buildActionButton(
                  icon: Icons.edit,
                  color: Colors.blueGrey,
                  label: '편집',
                  onTap: () {
                    // TODO
                  },
                ),
                _buildActionButton(
                  icon: Icons.report,
                  color: Colors.redAccent,
                  label: '신고',
                  onTap: () {
                    // TODO
                  },
                ),
              ],
            ),
            const SizedBox(height: 40),

            // 종료 버튼
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                shape: const StadiumBorder(),
                backgroundColor: Colors.grey,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 12,
                ),
              ),
              onPressed: () {
                // 단순 종료 => pop
                //Navigator.pop(context);

                // 또는 Navigator.pushNamedAndRemoveUntil(...)
              },
              child: const Text(
                '종료',
                style: TextStyle(fontSize: 18, color: Colors.white),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: 32),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.black)),
      ],
    );
  }
}
