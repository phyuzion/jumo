import 'package:flutter/material.dart';
// import 'package:flutter_contacts/flutter_contacts.dart'; // 제거
import 'package:mobile/utils/constants.dart';
import 'package:provider/provider.dart';
import 'package:mobile/controllers/blocked_numbers_controller.dart';
import 'package:mobile/graphql/phone_records_api.dart';
import 'dart:developer';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:mobile/services/native_methods.dart';
import 'package:mobile/controllers/contacts_controller.dart';
import 'package:mobile/models/phone_book_model.dart';

/// 신규: initialPhone==null => 전화번호 입력 가능
/// 기존: 전화번호 수정불가, contactId, memo, type 편집
class EditContactScreen extends StatefulWidget {
  final String? initialContactId;
  final String? initialRawContactId;
  final String? initialName;
  final String? initialPhone;
  final PhoneBookModel? initialContactModel;

  const EditContactScreen({
    super.key,
    this.initialContactId,
    this.initialRawContactId,
    this.initialName,
    this.initialPhone,
    this.initialContactModel,
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
    log(
      '[EditContactScreen] initState: initialContactId=${widget.initialContactId}, initialRawContactId=${widget.initialRawContactId}, initialName=${widget.initialName}, initialPhone=${widget.initialPhone}',
    );
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

  Future<void> _checkBlockedStatus() async {
    if (widget.initialPhone != null) {
      final normalizedPhone = normalizePhone(widget.initialPhone!);
      final blocknumbersController = context.read<BlockedNumbersController>();
      _isBlocked = await blocknumbersController.isNumberBlockedAsync(
        normalizedPhone,
      );
    }
  }

  // 1. 핵심 저장 로직 분리
  Future<bool> _performSaveOperation() async {
    final name = _nameCtrl.text.trim();
    final phone = normalizePhone(_phoneCtrl.text.trim());
    final memo = _memoCtrl.text.trim();

    if (name.isEmpty || phone.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('이름과 전화번호는 필수입니다.')));
      return false;
    }

    _showLoadingDialog();

    try {
      String? deviceContactId;
      final bool isUpdateOperation =
          widget.initialContactId != null &&
          widget.initialContactId!.isNotEmpty;

      // 이름 분리 (간단하게 firstName만 name 전체로, 나머지는 빈값)
      final firstName = name;
      final middleName = '';
      final lastName = '';
      final displayName = name;

      if (isUpdateOperation) {
        // 업데이트: rawContactId가 필수
        if (widget.initialRawContactId == null ||
            widget.initialRawContactId!.isEmpty) {
          throw Exception('연락처 ID가 없어 업데이트할 수 없습니다.');
        }
        log(
          '[EditContactScreen] Updating contact with rawContactId: ${widget.initialRawContactId}',
        );
        deviceContactId = await NativeMethods.upsertContact(
          rawContactId: widget.initialRawContactId,
          displayName: displayName,
          firstName: firstName,
          middleName: middleName,
          lastName: lastName,
          phoneNumber: phone,
        );
      } else {
        // 신규: id 없이 upsertContact 호출
        log('[EditContactScreen] Creating new contact');
        deviceContactId = await NativeMethods.upsertContact(
          displayName: displayName,
          firstName: firstName,
          middleName: middleName,
          lastName: lastName,
          phoneNumber: phone,
        );
      }

      final recordToUpsert = {
        'phoneNumber': phone,
        'name': name,
        'memo': memo.isNotEmpty ? memo : '',
        'type': _type,
        'createdAt':
            (widget.initialContactModel?.createdAt != null)
                ? widget.initialContactModel!.createdAt!
                    .toUtc()
                    .toIso8601String()
                : DateTime.now().toUtc().toIso8601String(),
      };
      await PhoneRecordsApi.upsertPhoneRecords([recordToUpsert]);

      if (mounted) Navigator.pop(context); // 로딩 다이얼로그 닫기
      return true; // 저장 성공
    } catch (e) {
      log('[EditContactScreen] _performSaveOperation error: $e');
      if (mounted) Navigator.pop(context); // 로딩 다이얼로그 닫기
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('저장 중 오류가 발생했습니다: $e')));
      }
      return false; // 저장 실패
    }
  }

  // 2. UI의 저장 버튼들이 호출할 함수 (저장 후 화면 닫기)
  Future<void> _handleMainSaveAction() async {
    bool success = await _performSaveOperation();
    if (success && mounted) {
      context.read<ContactsController>().syncContacts();
      Fluttertoast.showToast(msg: "저장 완료");
      Navigator.pop(context, true);
    }
  }

  Future<void> _toggleBlockStatus() async {
    if (widget.initialPhone == null) return;
    final normalizedPhone = normalizePhone(widget.initialPhone!);
    final blocknumbersController = context.read<BlockedNumbersController>();
    final isCurrentlyBlocked = await blocknumbersController
        .isNumberBlockedAsync(normalizedPhone);

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
        // 차단 해제 로직
        await blocknumbersController.removeBlockedNumber(normalizedPhone);
        setState(() {
          _isBlocked = false;
        });
        bool success = await _performSaveOperation();
        if (success && mounted) {
          context.read<ContactsController>().syncContacts();
          Fluttertoast.showToast(msg: "차단해제 완료");
        }
      } else {
        // 차단 및 '위험' 타입으로 설정 후 저장 로직
        setState(() {
          _type = 99; // 타입을 '위험'으로 설정
          _isBlocked = true; // 차단 상태로 UI 변경
        });
        await blocknumbersController.addBlockedNumber(normalizedPhone);
        bool success = await _performSaveOperation();
        if (success && mounted) {
          context.read<ContactsController>().syncContacts();
          Fluttertoast.showToast(msg: "차단 완료");
        }
      }
      // 화면은 여기서 닫지 않음
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _memoCtrl.dispose();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isNew ? '연락처 추가' : '연락처 편집'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _handleMainSaveAction,
          ),
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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0, left: 0),
                      child: Text(
                        "참고: '위험'으로 지정된 번호는 3명 이상 동일하게 지정 시, \n설정의 '위험번호 자동 차단' 기능에 따라 자동으로 차단될 수 있습니다.",
                        style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                      ),
                    ),
                  ],
                ),
              ],
              if (!isNew) ...[
                const SizedBox(height: 50),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _toggleBlockStatus,
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              _isBlocked ? Colors.red : Colors.grey[700],
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text(
                          _isBlocked ? '차단해제' : '차단',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 15), // 버튼 사이 간격
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _handleMainSaveAction,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue, // 저장 버튼 색상 (예: 파란색)
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text(
                          '등록',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
