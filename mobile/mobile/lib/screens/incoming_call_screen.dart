import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/native_methods.dart';
import '../controllers/contacts_controller.dart';

class IncomingCallScreen extends StatefulWidget {
  final String incomingNumber;
  const IncomingCallScreen({super.key, required this.incomingNumber});

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen> {
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
      if (phoneStr.contains(widget.incomingNumber)) {
        setState(() {
          _displayName = c.name as String?;
          _phones = phoneStr;
        });
        break;
      }
    }
  }

  Future<void> _acceptCall() async {
    await NativeMethods.acceptCall();
    // 수락 -> 전화가 STATE_ACTIVE -> onCall

    if (context.mounted) {
      Navigator.pushReplacementNamed(context, '/onCall', arguments: _phones);
    }
    if (!mounted) return;
  }

  Future<void> _rejectCall() async {
    await NativeMethods.rejectCall();
    // 거절 -> DISCONNECTED -> callEnded
    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final number = widget.incomingNumber;
    final contactName = _displayName ?? number; // fallback to number
    final contactPhones = _phones ?? number; // fallback

    return Scaffold(
      body: Stack(
        children: [
          // 2) 상단 정보
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 100),
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

                // "리스트 들어갈 곳"
                const Text(
                  '리스트 들어갈곳',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),

                // ex) Expanded(child: ListView(...))
                const Spacer(),
                // 4) 하단 전화 버튼(수락/거절)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildCallButton(
                      icon: Icons.call,
                      color: Colors.green,
                      label: '수락',
                      onTap: _acceptCall,
                    ),
                    _buildCallButton(
                      icon: Icons.call_end,
                      color: Colors.red,
                      label: '거절',
                      onTap: _rejectCall,
                    ),
                  ],
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /*
  Widget _buildBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1E1E2C), Color(0xFF2A2B5F)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
    );
  }
*/
  Widget _buildCallButton({
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
        Text(label, style: const TextStyle(color: Colors.white)),
      ],
    );
  }
}
