// lib/screens/recent_calls_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:mobile/controllers/call_log_controller.dart';
import 'package:mobile/controllers/contacts_controller.dart';
import 'package:mobile/models/phone_book_model.dart';
import 'package:mobile/screens/edit_contact_screen.dart';
import 'package:mobile/services/native_methods.dart';
import 'package:mobile/utils/app_event_bus.dart';
import 'package:provider/provider.dart';
import 'package:mobile/utils/constants.dart';

class RecentCallsScreen extends StatefulWidget {
  const RecentCallsScreen({super.key});

  @override
  State<RecentCallsScreen> createState() => _RecentCallsScreenState();
}

class _RecentCallsScreenState extends State<RecentCallsScreen> {
  final _callLogController = CallLogController();
  List<Map<String, dynamic>> _callLogs = [];
  StreamSubscription? _eventSub;

  @override
  void initState() {
    super.initState();
    _loadCalls();
    _eventSub = appEventBus.on<CallLogUpdatedEvent>().listen((event) {
      _loadCalls();
    });
  }

  @override
  void dispose() {
    _eventSub?.cancel();
    super.dispose();
  }

  Future<void> _loadCalls() async {
    final logs = _callLogController.getSavedCallLogs();
    setState(() => _callLogs = logs);
  }

  Future<void> _refreshCalls() async {
    await _callLogController.refreshCallLogs();
    await _loadCalls();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _refreshCalls,
        child: ListView.builder(
          itemCount: _callLogs.length,
          itemBuilder: (context, index) {
            final call = _callLogs[index];
            final number = call['number'] as String? ?? '';
            final name = call['name'] as String? ?? '';
            final callType = call['callType'] as String? ?? '';
            final ts = call['timestamp'] as int? ?? 0;

            final date = DateTime.fromMillisecondsSinceEpoch(ts);
            final dateStr = '${date.month}월 ${date.day}일';
            final timeStr =
                '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

            IconData iconData;
            Color iconColor;
            switch (callType) {
              case 'incoming':
                iconData = Icons.call_received;
                iconColor = Colors.green;
                break;
              case 'outgoing':
                iconData = Icons.call_made;
                iconColor = Colors.blue;
                break;
              case 'missed':
                iconData = Icons.call_missed;
                iconColor = Colors.red;
                break;
              default:
                iconData = Icons.phone;
                iconColor = Colors.grey;
            }

            return Slidable(
              key: ValueKey(index),
              endActionPane: ActionPane(
                motion: const BehindMotion(),
                children: [
                  SlidableAction(
                    onPressed: (_) => _onTapCall(number),
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    icon: Icons.call,
                  ),
                  SlidableAction(
                    onPressed: (_) => _onTapSearch(number),
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    icon: Icons.search,
                  ),
                  SlidableAction(
                    onPressed: (_) => _onTapEdit(number),
                    backgroundColor: Colors.blueGrey,
                    foregroundColor: Colors.white,
                    icon: Icons.edit,
                  ),
                ],
              ),
              child: ListTile(
                leading: Icon(iconData, color: iconColor, size: 28),
                title:
                    name.isNotEmpty
                        ? Text(name, style: const TextStyle(fontSize: 18))
                        : Text(number, style: const TextStyle(fontSize: 18)),
                subtitle:
                    name.isNotEmpty
                        ? Text(
                          number,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        )
                        : null,
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      dateStr,
                      style: const TextStyle(fontSize: 15, color: Colors.grey),
                    ),
                    Text(
                      timeStr,
                      style: const TextStyle(fontSize: 15, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _onTapCall(String number) async {
    await NativeMethods.makeCall(number);
  }

  void _onTapSearch(String number) {
    Navigator.pushNamed(context, '/search', arguments: number);
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

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => EditContactScreen(
              initialContactId:
                  existing.contactId.isNotEmpty ? existing.contactId : null,
              initialName: existing.name.isNotEmpty ? existing.name : '',
              initialPhone: isNew ? null : existing.phoneNumber,
              initialMemo: existing.memo ?? '',
              initialType: existing.type ?? 0,
            ),
      ),
    );

    if (result == true) {
      // 편집 후
      await contactsCtrl.syncContactsAll();
      // 필요하면 call log에도 업데이트
      // _callLogController.refreshCallLogs();
      // await _loadCalls();
    }
  }
}
