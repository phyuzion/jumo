import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
// ↑ flutter_contacts를 사용할 예정

class EditContactScreen extends StatefulWidget {
  final String? initialName;
  final String? initialPhone;
  final String? initialMemo;
  final int? initialType;

  const EditContactScreen({
    super.key,
    this.initialName,
    this.initialPhone,
    this.initialMemo,
    this.initialType,
  });

  @override
  State<EditContactScreen> createState() => _EditContactScreenState();
}

class _EditContactScreenState extends State<EditContactScreen> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _memoCtrl = TextEditingController();
  int _type = 0;

  @override
  void initState() {
    super.initState();
    _nameCtrl.text = widget.initialName ?? '';
    _phoneCtrl.text = widget.initialPhone ?? '';
    _memoCtrl.text = widget.initialMemo ?? '';
    _type = widget.initialType ?? 0;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _memoCtrl.dispose();
    super.dispose();
  }

  Future<void> _onSave() async {
    // 1) flutter_contacts 로 디바이스 연락처 추가/수정
    final name = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();

    if (name.isEmpty || phone.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('이름, 전화번호는 필수입니다.')));
      return;
    }

    // 예: 새 연락처 생성
    final newContact =
        Contact()
          ..name.first = name
          ..phones = [Phone(phone)];

    try {
      // flutter_contacts에서 제공하는 addContact
      final hasPermission = await FlutterContacts.requestPermission();
      if (!hasPermission) {
        // 권한 거부
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('주소록 권한이 필요합니다.')));
        return;
      }

      await newContact.insert(); // 디바이스 주소록에 새로 삽입

      // 2) 앱 내부적으로 memo/type은 따로 저장할 수도 있음
      //    -> ContactsController에서 별도 로직을 짜거나, 여기서 직접 GetStorage 등에 저장할 수도 있음

      // 저장 성공 후 화면 종료
      if (!mounted) return;
      Navigator.pop(context, true); // true 반환 -> 상위에서 새로고침 트리거
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('연락처 저장 오류: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('연락처 편집'),
        actions: [
          IconButton(icon: const Icon(Icons.check), onPressed: _onSave),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: '이름'),
            ),
            TextField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: '전화번호'),
            ),
            TextField(
              controller: _memoCtrl,
              decoration: const InputDecoration(labelText: '메모'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('타입:'),
                const SizedBox(width: 8),
                DropdownButton<int>(
                  value: _type,
                  items: const [
                    DropdownMenuItem(value: 0, child: Text('일반')),
                    DropdownMenuItem(value: 99, child: Text('위험')),
                    // ...
                  ],
                  onChanged: (val) => setState(() => _type = val ?? 0),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
