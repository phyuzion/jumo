import 'package:flutter/material.dart';
import 'package:mobile/controllers/contacts_controller.dart';
import 'package:provider/provider.dart';

class CallEndedScreen extends StatefulWidget {
  final String callEndedNumber;
  const CallEndedScreen({super.key, required this.callEndedNumber});

  @override
  State<CallEndedScreen> createState() => _CallEndedScreen();
}

class _CallEndedScreen extends State<CallEndedScreen> {
  String? _displayName;
  String? _phones;
  // or additional contact info
  // We'll search from contactsController

  @override
  void initState() {
    super.initState();
    _loadContactName();
  }

  /// 주소록(이미 저장) 에서 widget.incomingNumber 와 일치하는 contact 찾기
  Future<void> _loadContactName() async {
    final contactsController = context.read<ContactsController>();
    final contacts = contactsController.getSavedContacts();
    // e.g. each: {'name':'홍길동','phones':'010-1234-5678,...'}

    // 단순히 'phones' 에 widget.incomingNumber 가 포함되는지 검사 (문자열로)
    for (final c in contacts) {
      final phoneStr = c.phoneNumber as String? ?? '';
      if (phoneStr.contains(widget.callEndedNumber)) {
        setState(() {
          _displayName = c.name as String?;
          _phones = phoneStr;
        });
        break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final number = widget.callEndedNumber;
    final contactName = _displayName ?? number; // fallback to number
    final contactPhones = _phones ?? number; //

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 100),
            // 상단: 이름 / 번호
            Text(
              contactName,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              contactPhones,
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
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/home',
                  (route) => false,
                );

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
