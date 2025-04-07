// lib/screens/incoming_call_screen.dart
import 'package:flutter/material.dart';
import 'package:mobile/controllers/search_records_controller.dart';
import 'package:mobile/models/search_result_model.dart';
import 'package:mobile/models/today_record.dart';
import 'package:mobile/widgets/search_result_widget.dart';
import 'package:provider/provider.dart';
import 'package:mobile/services/native_methods.dart';
import 'package:mobile/controllers/contacts_controller.dart';
import 'package:mobile/models/phone_book_model.dart';
import 'package:mobile/services/local_notification_service.dart';
import 'package:mobile/utils/constants.dart';
import 'dart:developer';

class IncomingCallScreen extends StatefulWidget {
  final String incomingNumber;
  const IncomingCallScreen({super.key, required this.incomingNumber});

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen> {
  String? _displayName;
  String? _error;
  bool _loading = false;
  SearchResultModel? _result;

  @override
  void initState() {
    super.initState();
    _loadContactName();
    _loadSearchData();
    _showInitialIncomingNotification();
  }

  Future<void> _showInitialIncomingNotification() async {
    await LocalNotificationService.showIncomingCallNotification(
      id: 1234,
      callerName: '',
      phoneNumber: widget.incomingNumber,
    );
  }

  Future<void> _updateIncomingNotification(String name) async {
    await LocalNotificationService.showIncomingCallNotification(
      id: 1234,
      callerName: name,
      phoneNumber: widget.incomingNumber,
    );
  }

  Future<void> _loadSearchData() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final normalizedNumber = normalizePhone(widget.incomingNumber);
      final phoneData = await SearchRecordsController.searchPhone(
        normalizedNumber,
      );
      final todayRecords = await SearchRecordsController.searchTodayRecord(
        normalizedNumber,
      );

      final searchResult = SearchResultModel(
        phoneNumberModel: phoneData,
        todayRecords: todayRecords,
      );

      if (!mounted) return;
      setState(() {
        _result = searchResult;
      });
    } catch (e) {
      log('[IncomingCallScreen] Error loading search data: $e');
      if (mounted) setState(() => _error = '검색 정보를 불러오는데 실패했습니다.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadContactName() async {
    final contactsCtrl = context.read<ContactsController>();
    final normalizedNumber = normalizePhone(widget.incomingNumber);
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
          _displayName = contact!.name;
        });
        _updateIncomingNotification(contact.name);
      }
    } catch (e) {
      log('[IncomingCallScreen] Error loading contact name: $e');
    }
  }

  Future<void> _acceptCall() async {
    await NativeMethods.acceptCall();
    await LocalNotificationService.cancelNotification(1234);
  }

  Future<void> _rejectCall() async {
    await NativeMethods.rejectCall();
    await LocalNotificationService.cancelNotification(1234);
  }

  @override
  Widget build(BuildContext context) {
    final number = widget.incomingNumber;
    final displayName = _displayName ?? number;

    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 100),
                Text(
                  displayName,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 5),
                Text(
                  number,
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
        child: Text(_error!, style: const TextStyle(color: Colors.red)),
      );
    }
    if (_result == null) {
      return const Center(child: Text(''));
    }
    return SearchResultWidget(searchResult: _result!, ignorePointer: true);
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
        Text(label, style: const TextStyle(color: Colors.black)),
      ],
    );
  }
}
