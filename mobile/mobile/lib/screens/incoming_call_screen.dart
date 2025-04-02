// lib/screens/incoming_call_screen.dart
import 'package:flutter/material.dart';
import 'package:mobile/controllers/search_records_controller.dart';
import 'package:mobile/models/search_result_model.dart';
import 'package:mobile/models/today_record.dart';
import 'package:mobile/widgets/search_result_widget.dart';
import 'package:provider/provider.dart';
import '../services/native_methods.dart';
import '../controllers/contacts_controller.dart';
import 'package:mobile/services/local_notification_service.dart';
import 'package:flutter_background_service/flutter_background_service.dart';

class IncomingCallScreen extends StatefulWidget {
  final String incomingNumber;
  const IncomingCallScreen({super.key, required this.incomingNumber});

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen> {
  String? _displayName;
  String? _phones;
  String? _error;
  bool _loading = false;
  SearchResultModel? _result;

  @override
  void initState() {
    super.initState();
    _loadContactName();
    _loadSearchData();

    // 수신 알림 띄우기
    LocalNotificationService.showIncomingCallNotification(
      id: 1234,
      callerName: _displayName ?? '',
      phoneNumber: widget.incomingNumber,
    );
  }

  Future<void> _loadSearchData() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      // 전화번호 검색
      final phoneData = await SearchRecordsController.searchPhone(
        widget.incomingNumber,
      );

      // 오늘의 레코드 검색
      final todayRecords = await SearchRecordsController.searchTodayRecord(
        widget.incomingNumber,
      );

      final searchResult = SearchResultModel(
        phoneNumberModel: phoneData,
        todayRecords: todayRecords,
      );

      setState(() {
        _result = searchResult;
      });
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadContactName() async {
    final contactsController = context.read<ContactsController>();
    final contacts = contactsController.getContactsByPhones([
      widget.incomingNumber,
    ]);
    final contact = contacts[widget.incomingNumber];

    if (contact != null && mounted) {
      setState(() {
        _displayName = contact.name;
        _phones = contact.phoneNumber;
      });
    }
  }

  Future<void> _acceptCall() async {
    await NativeMethods.acceptCall();
    // 알림 닫기 (수신 알림)
    await LocalNotificationService.cancelNotification(1234);
  }

  Future<void> _rejectCall() async {
    await NativeMethods.rejectCall();
    // 수신 알림 닫기
    await LocalNotificationService.cancelNotification(1234);

    if (!mounted) return;
    //Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final number = widget.incomingNumber;
    final contactName = _displayName ?? number;
    final contactPhones = _phones ?? number;

    return Scaffold(
      body: Stack(
        children: [
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
                Expanded(child: _buildBody()),
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

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Text('에러: $_error', style: const TextStyle(color: Colors.red)),
      );
    }
    if (_result == null) {
      return const Center(
        child: Text('검색 결과가 없습니다.', style: TextStyle(color: Colors.grey)),
      );
    }
    return SearchResultWidget(searchResult: _result!);
  }

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
