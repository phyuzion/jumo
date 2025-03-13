import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:mobile/controllers/call_log_controller.dart';
import 'package:mobile/controllers/contacts_controller.dart';
import 'package:mobile/models/phone_book_model.dart';
import 'package:mobile/utils/constants.dart';
import 'package:provider/provider.dart';

/// 신규: initialPhone==null => 전화번호 입력 가능
/// 기존: 전화번호 수정불가, contactId, memo, type 편집
class EditContactScreen extends StatefulWidget {
  final String? initialContactId;
  final String? initialName;
  final String? initialPhone;
  final String? initialMemo;
  final int? initialType;

  const EditContactScreen({
    super.key,
    this.initialContactId,
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

  bool get isNew => widget.initialPhone == null; // null이면 신규

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
    final name = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    final memo = _memoCtrl.text.trim();

    if (name.isEmpty || phone.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('이름과 전화번호는 필수입니다.')));
      return;
    }

    // 1) 주소록 권한
    final hasPerm = await FlutterContacts.requestPermission();
    if (!hasPerm) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('주소록 권한이 필요합니다.')));
      return;
    }

    final contactsCtrl = context.read<ContactsController>();
    final callLogCtrl = context.read<CallLogController>();

    // === 디바이스 연락처 수정/추가 ===
    if (isNew) {
      // 신규 -> insert
      final contactId = await _insertDeviceContact(name, phone);
      final newItem = PhoneBookModel(
        contactId: contactId,
        name: name,
        phoneNumber: phone,
        memo: memo.isNotEmpty ? memo : null,
        type: _type != 0 ? _type : null,
        updatedAt: DateTime.now().toIso8601String(),
      );
      await contactsCtrl.addOrUpdateLocalRecord(newItem);
    } else {
      // 기존 연락처 업데이트
      await _updateDeviceContact(widget.initialContactId, name, phone);
      final newItem = PhoneBookModel(
        contactId: widget.initialContactId ?? '',
        name: name,
        phoneNumber: phone,
        memo: memo.isNotEmpty ? memo : null,
        type: _type != 0 ? _type : null,
        updatedAt: DateTime.now().toIso8601String(),
      );
      await contactsCtrl.addOrUpdateLocalRecord(newItem);
    }

    // === 전체 동기화 => 서버 업서트
    await contactsCtrl.syncContactsAll();
    await callLogCtrl.refreshCallLogs();

    if (!mounted) return;
    Navigator.pop(context, true);
  }

  /// 새 연락처 insert
  Future<String> _insertDeviceContact(String name, String phone) async {
    try {
      final c =
          Contact()
            ..name.last = ''
            ..name.first = name
            ..phones = [Phone(phone)];
      final inserted = await c.insert();
      return inserted.id;
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('새 연락처 추가 오류: $e')));
      return '';
    }
  }

  /// 기존 연락처 수정
  Future<void> _updateDeviceContact(
    String? contactId,
    String name,
    String phone,
  ) async {
    try {
      Contact? found;

      // 1) contactId로 먼저 시도
      if (contactId != null && contactId.isNotEmpty) {
        found = await FlutterContacts.getContact(
          contactId,
          withProperties: true,
          withAccounts: true, // <-- 수정
          withPhoto: true,
          withThumbnail: true,
        );
      }

      // 2) fallback: phone 매칭
      if (found == null) {
        final all = await FlutterContacts.getContacts(
          withProperties: true,
          withAccounts: true, // <-- 수정
          withPhoto: true,
          withThumbnail: true,
        );
        for (final c in all) {
          if (c.phones.isEmpty) continue;
          for (final p in c.phones) {
            if (normalizePhone(p.number) == normalizePhone(phone)) {
              found = c;
              break;
            }
          }
          if (found != null) break;
        }
      }

      // 3) 그래도 없으면 insert
      if (found == null) {
        await _insertDeviceContact(name, phone);
        return;
      }

      // 4) update
      found.name.last = '';
      found.name.first = name;
      await found.update();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('연락처 수정 오류: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isNew ? '연락처 추가' : '연락처 편집'),
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
              enabled: isNew, // 기존이면 수정 불가
            ),
            TextField(
              controller: _memoCtrl,
              decoration: const InputDecoration(labelText: '메모'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('타입:'),
                const SizedBox(width: 10),
                DropdownButton<int>(
                  value: _type,
                  items: const [
                    DropdownMenuItem(value: 0, child: Text('일반')),
                    DropdownMenuItem(value: 99, child: Text('위험')),
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
