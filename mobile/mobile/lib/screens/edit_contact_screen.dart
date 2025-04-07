import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:mobile/controllers/call_log_controller.dart';
import 'package:mobile/controllers/contacts_controller.dart';
import 'package:mobile/models/phone_book_model.dart';
import 'package:mobile/utils/constants.dart';
import 'package:provider/provider.dart';
import 'package:mobile/controllers/blocked_numbers_controller.dart';
import 'package:mobile/graphql/phone_records_api.dart';
import 'dart:developer';

/// 신규: initialPhone==null => 전화번호 입력 가능
/// 기존: 전화번호 수정불가, contactId, memo, type 편집
class EditContactScreen extends StatefulWidget {
  final String? initialContactId;
  final String? initialName;
  final String? initialPhone;

  const EditContactScreen({
    super.key,
    this.initialContactId,
    this.initialName,
    this.initialPhone,
  });

  @override
  State<EditContactScreen> createState() => _EditContactScreenState();
}

class _EditContactScreenState extends State<EditContactScreen> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _memoCtrl = TextEditingController();
  int _type = 0;
  bool _isBlocked = false;
  bool _isLoadingDetails = false;

  bool get isNew => widget.initialPhone == null;

  @override
  void initState() {
    super.initState();
    _nameCtrl.text = widget.initialName ?? '';
    _phoneCtrl.text = widget.initialPhone ?? '';
    _checkBlockedStatus();

    if (!isNew && widget.initialPhone != null) {
      _loadContactDetails(widget.initialPhone!);
    }
  }

  Future<void> _loadContactDetails(String phoneNumber) async {
    setState(() {
      _isLoadingDetails = true;
    });
    try {
      final record = await PhoneRecordsApi.getPhoneRecord(
        normalizePhone(phoneNumber),
      );
      if (record != null && mounted) {
        setState(() {
          _memoCtrl.text = record['memo'] as String? ?? '';
          _type = record['type'] as int? ?? 0;
        });
      }
    } catch (e) {
      log('[EditContactScreen] Failed to load details: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('연락처 상세 정보를 불러오는데 실패했습니다.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingDetails = false;
        });
      }
    }
  }

  void _checkBlockedStatus() {
    if (widget.initialPhone != null) {
      final normalizedPhone = normalizePhone(widget.initialPhone!);
      final blocknumbersController = context.read<BlockedNumbersController>();
      _isBlocked = blocknumbersController.isNumberBlocked(normalizedPhone);
    }
  }

  Future<void> _toggleBlockStatus() async {
    if (widget.initialPhone == null) return;
    final normalizedPhone = normalizePhone(widget.initialPhone!);

    final blocknumbersController = context.read<BlockedNumbersController>();
    final isCurrentlyBlocked = blocknumbersController.isNumberBlocked(
      normalizedPhone,
    );

    final confirmMessage = isCurrentlyBlocked ? '차단해제 하시겠습니까?' : '차단 하시겠습니까?';

    final result = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('확인'),
            content: Text(confirmMessage),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('아니오'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('네'),
              ),
            ],
          ),
    );

    if (result == true) {
      if (isCurrentlyBlocked) {
        await blocknumbersController.removeBlockedNumber(normalizedPhone);
      } else {
        await blocknumbersController.addBlockedNumber(normalizedPhone);
      }
      setState(() {
        _isBlocked = !isCurrentlyBlocked;
      });
    }
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
    final phone = normalizePhone(_phoneCtrl.text.trim());
    final memo = _memoCtrl.text.trim();

    if (name.isEmpty || phone.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('이름과 전화번호는 필수입니다.')));
      return;
    }

    final hasPerm = await FlutterContacts.requestPermission();
    if (!hasPerm) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('주소록 권한이 필요합니다.')));
      return;
    }

    _showLoadingDialog();

    try {
      if (isNew) {
        await _insertDeviceContact(name, phone);
      } else {
        await _updateDeviceContact(widget.initialContactId, name);
      }

      final recordToUpsert = {
        'phoneNumber': phone,
        'name': name,
        'memo': memo.isNotEmpty ? memo : '',
        'type': _type,
        'createdAt': DateTime.now().toUtc().toIso8601String(),
      };
      await PhoneRecordsApi.upsertPhoneRecords([recordToUpsert]);

      Navigator.pop(context);

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      log('[EditContactScreen] _onSave error: $e');
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('저장 중 오류가 발생했습니다: $e')));
      }
    }
  }

  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return const Center(child: CircularProgressIndicator());
      },
    );
  }

  Future<String> _insertDeviceContact(String name, String phone) async {
    try {
      final contactToInsert = Contact(
        name: Name(first: name),
        phones: [Phone(phone)],
      );
      final insertedContact = await contactToInsert.insert();
      log('[EditContactScreen] Inserted device contact: ${insertedContact.id}');
      return insertedContact.id;
    } catch (e) {
      log('[EditContactScreen] _insertDeviceContact error: $e');
      rethrow;
    }
  }

  Future<void> _updateDeviceContact(String? contactId, String name) async {
    Contact? foundContact;

    if (contactId != null && contactId.isNotEmpty) {
      try {
        foundContact = await FlutterContacts.getContact(
          contactId,
          withProperties: true,
          withAccounts: true,
        );
      } catch (e) {
        log('[EditContactScreen] Failed to get contact by ID $contactId: $e');
      }
    }

    if (foundContact == null && widget.initialPhone != null) {
      final normalizedPhone = normalizePhone(widget.initialPhone!);
      try {
        final allContacts = await FlutterContacts.getContacts(
          withProperties: true,
          withAccounts: true,
        );
        for (final c in allContacts) {
          if (c.phones.any(
            (p) => normalizePhone(p.number) == normalizedPhone,
          )) {
            foundContact = c;
            log('[EditContactScreen] Found contact by phone fallback: ${c.id}');
            break;
          }
        }
      } catch (e) {
        log(
          '[EditContactScreen] Failed to search contact by phone $normalizedPhone: $e',
        );
        throw Exception('디바이스에서 연락처를 찾을 수 없습니다.');
      }
    }

    if (foundContact == null) {
      log(
        '[EditContactScreen] Contact not found for update (ID: $contactId, Phone: ${widget.initialPhone})',
      );
      throw Exception('수정할 연락처를 디바이스에서 찾을 수 없습니다.');
    }

    bool needsUpdate = false;
    final newName = Name(first: name);
    if (foundContact.name.first != newName.first ||
        foundContact.name.last != newName.last ||
        foundContact.name.middle != newName.middle) {
      foundContact.name = newName;
      needsUpdate = true;
    }

    if (needsUpdate) {
      try {
        await foundContact.update();
        log(
          '[EditContactScreen] Updated device contact name for ${foundContact.id}',
        );
      } catch (e) {
        log(
          '[EditContactScreen] _updateDeviceContact error for ${foundContact.id}: $e',
        );
        rethrow;
      }
    } else {
      log(
        '[EditContactScreen] Device contact name is already up-to-date for ${foundContact.id}.',
      );
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
        child: SingleChildScrollView(
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
                enabled: isNew,
              ),
              const SizedBox(height: 12),
              if (_isLoadingDetails)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16.0),
                  child: Center(child: CircularProgressIndicator()),
                )
              else ...[
                TextField(
                  controller: _memoCtrl,
                  decoration: const InputDecoration(labelText: '메모 (선택)'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('타입 (선택):'),
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
              if (!isNew) ...[
                const SizedBox(height: 16),
                InkWell(
                  onTap: _toggleBlockStatus,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: _isBlocked ? Colors.red : Colors.black,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Center(
                      child: Text(
                        _isBlocked ? '차단 상태입니다.' : '정상 상태입니다.',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
