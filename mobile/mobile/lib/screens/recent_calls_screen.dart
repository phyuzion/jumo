// recent_calls_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mobile/controllers/call_log_controller.dart';
import 'package:mobile/controllers/contacts_controller.dart'; // ContactsController 사용
import 'package:mobile/services/native_default_dialer_methods.dart';
// constants의 normalizePhone, formatDateOnly, formatTimeOnly 등 사용
import 'package:mobile/utils/constants.dart';
import 'package:provider/provider.dart'; // context.read()
import 'package:mobile/models/phone_book_model.dart';
import 'package:mobile/screens/edit_contact_screen.dart';
import 'package:mobile/services/native_methods.dart';
import 'package:mobile/widgets/custom_expansion_tile.dart';
import 'dart:developer';

class RecentCallsScreen extends StatefulWidget {
  const RecentCallsScreen({super.key});

  @override
  State<RecentCallsScreen> createState() => _RecentCallsScreenState();
}

class _RecentCallsScreenState extends State<RecentCallsScreen>
    with WidgetsBindingObserver {
  bool _isDefaultDialer = false;
  final _scrollController = ScrollController();
  int? _expandedIndex;

  @override
  void initState() {
    super.initState();
    log('[RecentCallsScreen] initState called.');
    WidgetsBinding.instance.addObserver(this);
    _checkDefaultDialer();
    _scrollController.addListener(() {
      /* ... */
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _checkDefaultDialer();
    }
  }

  Future<void> _checkDefaultDialer() async {
    final isDefault = await NativeDefaultDialerMethods.isDefaultDialer();
    if (!mounted) return;
    setState(() => _isDefaultDialer = isDefault);
  }

  Future<void> _refreshCalls() async {
    log('[RecentCallsScreen] Refreshing calls and contacts...');
    context.read<ContactsController>().invalidateCache();
    await context.read<CallLogController>().refreshCallLogs();
    await context.read<ContactsController>().getLocalContacts(
      forceRefresh: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    log('[RecentCallsScreen] build called.');
    final callLogProvider = context.watch<CallLogController>();
    final contactsProvider = context.watch<ContactsController>();
    final callLogs = callLogProvider.callLogs;
    final contacts = contactsProvider.contacts;
    final contactCache = {for (var c in contacts) c.phoneNumber: c};
    final isLoading = callLogProvider.isLoading || contactsProvider.isLoading;

    log(
      '[RecentCallsScreen] build: isLoading=$isLoading, callLogs count: ${callLogs.length}',
    );

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(40),
        child: AppBar(
          title: const Text(
            '최근기록',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh, size: 24),
              onPressed: _refreshCalls,
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refreshCalls,
        child:
            isLoading
                ? const Center(child: CircularProgressIndicator())
                : callLogs.isEmpty
                ? Center(child: Text('최근 통화 기록이 없습니다.'))
                : ListView.builder(
                  controller: _scrollController,
                  itemCount: callLogs.length,
                  itemBuilder: (context, index) {
                    final call = callLogs[index];
                    final number = call['number'] as String? ?? '';
                    final callType = call['callType'] as String? ?? '';
                    final ts = call['timestamp'] as int? ?? 0;

                    final normalizedNumber = normalizePhone(number);
                    final contact = contactCache[normalizedNumber];

                    final dateStr = formatDateOnly(ts.toString());
                    final timeStr = formatTimeOnly(ts.toString());

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

                    final displayName = contact?.name ?? number;

                    return Column(
                      children: [
                        if (index > 0)
                          const Divider(
                            color: Colors.grey,
                            thickness: 0.5,
                            indent: 16.0,
                            endIndent: 16.0,
                            height: 0,
                          ),
                        CustomExpansionTile(
                          key: ValueKey('${number}_$ts'),
                          isExpanded: index == _expandedIndex,
                          onTap: () {
                            setState(() {
                              _expandedIndex =
                                  index == _expandedIndex ? null : index;
                            });
                          },
                          leading: Icon(iconData, color: iconColor),
                          title: Text(displayName),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                dateStr,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                              Text(
                                timeStr,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                if (_isDefaultDialer)
                                  _buildActionButton(
                                    icon: Icons.call,
                                    color: Colors.green,
                                    onPressed: () => _onTapCall(number),
                                  ),
                                _buildActionButton(
                                  icon: Icons.message,
                                  color: Colors.blue,
                                  onPressed: () => _onTapMessage(number),
                                ),
                                _buildActionButton(
                                  icon: Icons.search,
                                  color: Colors.orange,
                                  onPressed: () => _onTapSearch(number),
                                ),
                                _buildActionButton(
                                  icon: Icons.edit,
                                  color: Colors.blueGrey,
                                  onPressed: () => _onTapEdit(number, contact),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color),
        ),
      ),
    );
  }

  Future<void> _onTapMessage(String number) async {
    await NativeMethods.openSmsApp(number);
  }

  Future<void> _onTapCall(String number) async {
    await NativeMethods.makeCall(number);
  }

  void _onTapSearch(String number) {
    Navigator.pushNamed(
      context,
      '/search',
      arguments: {'number': number, 'isRequested': false},
    );
  }

  Future<void> _onTapEdit(String number, PhoneBookModel? contact) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => EditContactScreen(
              initialContactId: contact?.contactId,
              initialName: contact?.name ?? '',
              initialPhone: normalizePhone(number),
            ),
      ),
    );
    if (result == true) {
      await _refreshCalls();
    }
  }
}
