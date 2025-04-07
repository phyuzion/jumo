import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:mobile/controllers/blocked_numbers_controller.dart';
import 'package:mobile/controllers/call_log_controller.dart';
import 'package:mobile/controllers/contacts_controller.dart';
import 'package:mobile/services/local_notification_service.dart';
import 'package:mobile/utils/constants.dart';
import 'package:provider/provider.dart';
import 'dart:developer'; // 로그 추가

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
  // String? _phones; // 제거

  @override
  void initState() {
    super.initState();
    _loadContactName(); // 비동기 이름 로드
    _updateCallLog();
    _stopOnCallNoti();

    if (widget.callEndedReason == 'missed') {
      _showMissedCallNotification(); // 이름 로드 후 호출되도록 이동 고려
    }
  }

  Future<void> _stopOnCallNoti() async {
    final service = FlutterBackgroundService();
    service.invoke('stopCallTimer');
    await LocalNotificationService.cancelNotification(
      1234,
    ); // Incoming call noti
    await LocalNotificationService.cancelNotification(
      9999,
    ); // Ongoing call noti
  }

  Future<void> _showMissedCallNotification() async {
    // 이름 로드될 때까지 잠시 대기 (선택적)
    // await Future.delayed(const Duration(milliseconds: 300));
    final callerName = _displayName ?? ''; // 로드된 이름 사용
    LocalNotificationService.showMissedCallNotification(
      id: 3000,
      callerName: callerName,
      phoneNumber: widget.callEndedNumber,
    );
  }

  void _updateCallLog() {
    // refreshCallLogs는 비동기일 수 있으므로 async/await 처리 고려
    // context 사용 시 주의 (initState 완료 전 사용 불가)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<CallLogController>().refreshCallLogs();
      }
    });
  }

  // 연락처 이름 비동기 로드
  Future<void> _loadContactName() async {
    final contactsCtrl = context.read<ContactsController>();
    final normalizedNumber = normalizePhone(widget.callEndedNumber);
    try {
      final contacts = await contactsCtrl.getLocalContacts();
      PhoneBookModel? contact;
      try {
        contact = contacts.firstWhere((c) => c.phoneNumber == normalizedNumber);
      } catch (e) {
        contact = null;
      }

      if (contact != null && mounted) {
        setState(() {
          _displayName = contact!.name; // null 단언 추가
        });
        // 부재중 전화 알림 업데이트 (이름 로드 후)
        if (widget.callEndedReason == 'missed') {
          _showMissedCallNotification();
        }
      }
    } catch (e) {
      log('[CallEndedScreen] Error loading contact name: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final number = widget.callEndedNumber;
    final reason = widget.callEndedReason;
    // 표시 이름: 로드된 이름 우선, 없으면 원본 번호
    final displayName = _displayName ?? number;
    // final contactPhones = _phones ?? number; // 제거

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
            Text(
              displayName, // 수정된 이름 표시
              style: const TextStyle(
                color: Colors.black,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 5),
            Text(
              number, // 원본 번호 표시
              style: const TextStyle(color: Colors.black, fontSize: 16),
            ),
            const SizedBox(height: 20),
            Text(
              statusMessage,
              style: TextStyle(
                fontSize: 18,
                color: reason == 'missed' ? Colors.orange : Colors.red,
              ),
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildActionButton(
                  icon: Icons.search,
                  color: Colors.orange,
                  label: '검색',
                  onTap: () {
                    // 검색 화면으로 정규화된 번호 전달
                    Navigator.pushNamed(
                      context,
                      '/search',
                      arguments: {
                        'number': normalizePhone(number),
                        'isRequested': false,
                      },
                    );
                  },
                ),
                _buildActionButton(
                  icon: Icons.edit,
                  color: Colors.blueGrey,
                  label: '편집',
                  // 편집 화면으로 로드된 정보 전달
                  onTap: () => _onTapEdit(number, _displayName),
                ),
                _buildActionButton(
                  icon: Icons.block,
                  color: Colors.red,
                  label: '차단',
                  onTap: () async {
                    final normalizedNumber = normalizePhone(number); // 정규화
                    final blocknumbersController =
                        context.read<BlockedNumbersController>();
                    try {
                      await blocknumbersController.addBlockedNumber(
                        normalizedNumber,
                      );
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('전화번호가 차단되었습니다.'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                    } catch (e) {
                      log('[CallEndedScreen] Error blocking number: $e');
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('차단 중 오류 발생: $e')),
                        );
                      }
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 40),
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

  /// 편집 아이콘 탭
  Future<void> _onTapEdit(String number, String? displayName) async {
    final norm = normalizePhone(number);
    // EditContactScreen으로 로드된 이름과 정규화된 번호 전달
    // contactId는 EditContactScreen 내부에서 fallback 로직으로 찾음
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => EditContactScreen(
              // initialContactId는 전달 안 함 (EditContactScreen에서 찾음)
              initialName: displayName ?? '',
              initialPhone: norm,
            ),
      ),
    );
    // 편집 후 돌아왔을 때 화면 갱신 불필요 (이미 종료 화면임)
  }
}
