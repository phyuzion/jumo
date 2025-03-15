import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:mobile/controllers/call_log_controller.dart';
import 'package:mobile/controllers/contacts_controller.dart';
import 'package:mobile/services/local_notification_service.dart';
import 'package:mobile/utils/constants.dart';
import 'package:provider/provider.dart';

import 'package:mobile/models/phone_book_model.dart';
import 'package:mobile/screens/edit_contact_screen.dart';

class CallEndedScreen extends StatefulWidget {
  final String callEndedNumber;
  final String callEndedReason;

  const CallEndedScreen({
    super.key,
    required this.callEndedNumber,
    required this.callEndedReason,
  });

  @override
  State<CallEndedScreen> createState() => _CallEndedScreen();
}

class _CallEndedScreen extends State<CallEndedScreen> {
  String? _displayName;
  String? _phones;

  @override
  void initState() {
    super.initState();
    _loadContactName();
    _updateCallLog();

    _stopOnCallNoti();
    // (옵션) reason=='missed' -> showMissedCallNotification
    if (widget.callEndedReason == 'missed') {
      _showMissedCallNotification();
    }
  }

  Future<void> _stopOnCallNoti() async {
    //이건 혹시 모르니까 넣어둠.
    final service = FlutterBackgroundService();
    service.invoke('stopCallTimer');

    await LocalNotificationService.cancelNotification(9999);
  }

  void _showMissedCallNotification() {
    // e.g. id=3000
    // 'callerName' = _displayName ?? widget.callEndedNumber
    final callerName = _displayName ?? '';
    LocalNotificationService.showMissedCallNotification(
      id: 3000,
      callerName: callerName,
      phoneNumber: widget.callEndedNumber,
    );
  }

  void _updateCallLog() {
    final callLogController = context.read<CallLogController>();
    callLogController.refreshCallLogs();
  }

  /// 주소록(이미 저장) 에서 widget.incomingNumber 와 일치하는 contact 찾기
  Future<void> _loadContactName() async {
    final contactsController = context.read<ContactsController>();
    final contacts = contactsController.getSavedContacts();

    for (final c in contacts) {
      final phoneStr = c.phoneNumber ?? '';
      final normPhone = normalizePhone(phoneStr);

      if (normPhone == normalizePhone(widget.callEndedNumber)) {
        setState(() {
          _displayName = c.name;
          _phones = normPhone;
        });
        break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final number = widget.callEndedNumber;
    final reason = widget.callEndedReason; // 'missed' or 'ended' etc.
    final contactName = _displayName ?? number;
    final contactPhones = _phones ?? number;

    // reason 에 따라 문구 분기
    String statusMessage;
    if (reason == 'missed') {
      statusMessage = '부재중 전화입니다.';
    } else {
      statusMessage = '통화가 종료되었습니다.';
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 100),

            // 이름 / 번호
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

            // reason 에 따른 안내 문구
            Text(
              statusMessage,
              style: TextStyle(
                fontSize: 18,
                color: reason == 'missed' ? Colors.orange : Colors.red,
              ),
            ),

            const Spacer(),

            // 검색, 편집, 신고 액션
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildActionButton(
                  icon: Icons.search,
                  color: Colors.orange,
                  label: '검색',
                  onTap: () {
                    Navigator.pushNamed(context, '/search', arguments: _phones);
                  },
                ),
                _buildActionButton(
                  icon: Icons.edit,
                  color: Colors.blueGrey,
                  label: '편집',
                  onTap: () => _onTapEdit(number),
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
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/home',
                  (route) => false,
                );
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

  /// 편집 아이콘 탭:
  /// 1) phoneBook 에 있는지 -> 기존이면 EditContactScreen(기존 모드)
  /// 2) 없으면 신규 모드
  Future<void> _onTapEdit(String number) async {
    final norm = normalizePhone(number);
    final contactsCtrl = context.read<ContactsController>();
    final localList = contactsCtrl.getSavedContacts();
    final existing = localList.firstWhere(
      (c) => c.phoneNumber == norm,
      orElse:
          () => PhoneBookModel(
            contactId: '',
            name: '',
            phoneNumber: norm,
            memo: null,
            type: null,
            updatedAt: null,
          ),
    );
    final isNew = (existing.updatedAt == null);

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => EditContactScreen(
              initialContactId:
                  existing.contactId.isNotEmpty ? existing.contactId : null,
              initialName: existing.name.isNotEmpty ? existing.name : '',
              initialPhone: isNew ? norm : existing.phoneNumber,
              initialMemo: existing.memo ?? '',
              initialType: existing.type ?? 0,
            ),
      ),
    );
  }
}
