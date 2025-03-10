import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:mobile/controllers/contacts_controller.dart';
import 'package:mobile/models/phone_book_model.dart';
import 'package:mobile/utils/constants.dart';
import 'package:provider/provider.dart';

/// EditContactScreen
/// - 신규: initialPhone == null → 폰번호 입력 가능
/// - 기존: initialPhone != null → 폰번호 read-only
class EditContactScreen extends StatefulWidget {
  final String? initialContactId; // 새 필드
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

  String get contactId => widget.initialContactId ?? '';
  bool get isNew => widget.initialPhone == null;

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
    final type = _type;

    if (name.isEmpty || phone.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('이름과 전화번호는 필수입니다.')));
      return;
    }

    final hasPermission = await FlutterContacts.requestPermission();
    if (!hasPermission) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('주소록 권한이 필요합니다.')));
      return;
    }

    final ContactsController contactsController =
        context.read<ContactsController>();
    if (isNew) {
      // 1) 새 연락처 -> insert, 반환된 contact.id 저장
      final createdContactId = await _insertDeviceContact(name, phone);
      // 로컬 phonebook에도 추가 (메모/타입)
      final list = contactsController.getSavedContacts();
      final exists = list.any((x) => x.phoneNumber == phone);
      if (!exists) {
        list.add(
          PhoneBookModel(
            contactId: createdContactId,
            name: name,
            phoneNumber: phone,
            memo: memo.isNotEmpty ? memo : null,
            type: type == 0 ? null : type,
            updatedAt: DateTime.now().toIso8601String(),
          ),
        );
        await contactsController.saveLocalPhoneBook(list);
      } else {
        // 혹시나 race condition
        // 그냥 updateMemoAndType
        await contactsController.updateMemoAndType(
          phoneNumber: phone,
          memo: memo,
          type: type,
          updatedName: name,
        );
      }
    } else {
      // 2) 기존 연락처 -> update (이름만)
      await _updateDeviceContact(contactId, name, phone);
      // 로컬 memo/type 갱신
      await contactsController.updateMemoAndType(
        phoneNumber: phone,
        memo: memo,
        type: type,
        updatedName: name,
      );
    }

    // 마지막으로 refreshContactsWithDiff
    await contactsController.refreshContactsWithDiff();
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  /// 신규 연락처 삽입 -> return contact.id
  Future<String> _insertDeviceContact(String name, String phone) async {
    try {
      final newContact =
          Contact()
            ..name.first = name
            ..phones = [Phone(phone)];
      // insert() 는 void가 아니라 새로 삽입된 Contact를 반환
      final inserted = await newContact.insert();
      return inserted.id; // 여기서 contact.id 얻기
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('디바이스 연락처 추가 오류: $e')));
      return '';
    }
  }

  /// 기존 연락처 수정 -> contactId로 찾고, 없으면 전화번호로 찾는다
  Future<void> _updateDeviceContact(
    String contactId,
    String name,
    String phone,
  ) async {
    try {
      // 우선 contactId로 가져오기 시도
      Contact? found;
      if (contactId.isNotEmpty) {
        found = await FlutterContacts.getContact(
          contactId,
          withProperties: true,
        );
      }
      if (found == null) {
        // fallback: 전화번호로 찾기
        final all = await FlutterContacts.getContacts(withProperties: true);
        for (var c in all) {
          if (c.phones.any(
            (p) => normalizePhone(p.number) == normalizePhone(phone),
          )) {
            found = c;
            break;
          }
        }
      }
      if (found == null) {
        // 못 찾으면 새로 insert
        await _insertDeviceContact(name, phone);
        return;
      }

      // 찾았으면 name만 업데이트
      found.name.first = name;
      // phone 수정 안 함
      await found.update();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('디바이스 연락처 수정 오류: $e')));
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
            // 이름
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: '이름'),
            ),
            // 전화번호
            TextField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: '전화번호'),
              enabled: isNew, // 기존 연락처면 수정 불가
            ),
            // 메모
            TextField(
              controller: _memoCtrl,
              decoration: const InputDecoration(labelText: '메모'),
            ),
            const SizedBox(height: 12),
            // 타입
            Row(
              children: [
                const Text('타입:'),
                const SizedBox(width: 8),
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
