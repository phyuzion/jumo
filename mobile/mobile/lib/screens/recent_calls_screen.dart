// recent_calls_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:mobile/controllers/call_log_controller.dart';
import 'package:mobile/controllers/contacts_controller.dart'; // ContactsController for name lookup
import 'package:mobile/services/native_default_dialer_methods.dart';
import 'package:mobile/utils/app_event_bus.dart';
import 'package:mobile/utils/constants.dart'; // normalizePhone, etc.
import 'package:provider/provider.dart'; // context.read()
import 'package:mobile/models/phone_book_model.dart';
import 'package:mobile/screens/edit_contact_screen.dart';
import 'package:mobile/services/native_methods.dart';

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
    // callLog이 변경될 때마다(예: refreshCallLogs) => _loadCalls
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
    // 로컬DB 반영 뒤 _loadCalls() 재호출
    await _loadCalls();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _refreshCalls,
        child: ListView.separated(
          itemCount: _callLogs.length,
          separatorBuilder:
              (context, index) => const Divider(
                color: Colors.grey,
                thickness: 0.5,
                indent: 16.0,
                endIndent: 16.0,
                height: 0,
              ),
          itemBuilder: (context, index) {
            final call = _callLogs[index];
            final number = call['number'] as String? ?? '';
            final callType = call['callType'] as String? ?? '';
            final ts = call['timestamp'] as int? ?? 0;

            // === 날짜/시간 표시
            final date = DateTime.fromMillisecondsSinceEpoch(ts);
            final dateStr = '${date.month}월 ${date.day}일';
            final timeStr =
                '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

            // === 아이콘
            IconData iconData;
            Color iconColor;
            switch (callType.toLowerCase()) {
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

            // === 이름 lookup
            final contactsCtrl = context.read<ContactsController>();
            final phoneNormalized = normalizePhone(number);
            final contact = contactsCtrl.getSavedContacts().firstWhere(
              (c) => c.phoneNumber == phoneNormalized,
              orElse:
                  () => PhoneBookModel(
                    contactId: '',
                    name: '',
                    phoneNumber: phoneNormalized,
                    memo: null,
                    type: null,
                    updatedAt: null,
                  ),
            );
            final name = contact.name; // 없으면 ''

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
                // 만약 이름이 있으면 title=이름, subtitle=번호 / 없으면 title=번호
                title: Text(
                  name.isNotEmpty ? name : number,
                  style: const TextStyle(fontSize: 16),
                ),
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
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    Text(
                      timeStr,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
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

    // if (await NativeDefaultDialerMethods.isDefaultDialer()) {
    //   Navigator.of(context).pushNamed('/onCall', arguments: number);
    // }
  }

  void _onTapSearch(String number) {
    Navigator.pushNamed(context, '/search', arguments: number);
  }

  Future<void> _onTapEdit(String number) async {
    final phoneNormalized = normalizePhone(number);
    // ContactsController에서 해당 번호를 찾아서 편집화면으로
    final contactsCtrl = context.read<ContactsController>();
    final list = contactsCtrl.getSavedContacts();
    final existing = list.firstWhere(
      (c) => c.phoneNumber == phoneNormalized,
      orElse:
          () => PhoneBookModel(
            contactId: '',
            name: '',
            phoneNumber: phoneNormalized,
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
              initialPhone: isNew ? phoneNormalized : existing.phoneNumber,
              initialMemo: existing.memo ?? '',
              initialType: existing.type ?? 0,
            ),
      ),
    );
  }
}
