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
import 'package:mobile/providers/recent_history_provider.dart';

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
    WidgetsBinding.instance.addObserver(this);
    _checkDefaultDialer();
    _scrollController.addListener(() {});
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
    if (!mounted) {
      return;
    }
    setState(() => _isDefaultDialer = isDefault);
  }

  Future<void> _refreshHistory() async {
    log('[_RecentCallsScreenState._refreshHistory] Called.');
    await context.read<RecentHistoryProvider>().refresh();
  }

  @override
  Widget build(BuildContext context) {
    final recentHistoryProvider = context.watch<RecentHistoryProvider>();
    final recentHistory = recentHistoryProvider.recentHistoryList;

    final contacts = context.select((ContactsController cc) {
      return cc.contacts;
    });
    final areContactsLoading = context.select((ContactsController cc) {
      return cc.isLoading;
    });

    final contactCache = {for (var c in contacts) c.phoneNumber: c};
    final isLoading = areContactsLoading;

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
              onPressed: () {
                _refreshHistory();
              },
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _refreshHistory();
        },
        child:
            isLoading
                ? const Center(child: CircularProgressIndicator())
                : recentHistory.isEmpty
                ? Center(child: Text('최근 통화/문자 기록이 없습니다.'))
                : ListView.builder(
                  controller: _scrollController,
                  itemCount: recentHistory.length,
                  itemBuilder: (context, index) {
                    final item = recentHistory[index];
                    final historyType =
                        item['historyType'] as String? ?? 'call';

                    String number;
                    String? body;
                    String? callType;
                    int ts;
                    String? smsType;

                    if (historyType == 'call') {
                      number = item['number'] as String? ?? '';
                      callType = item['callType'] as String? ?? '';
                      ts = item['timestamp'] as int? ?? 0;
                    } else {
                      number =
                          item['address'] as String? ??
                          item['number'] as String? ??
                          '';
                      body = item['body'] as String?;
                      ts = item['date'] as int? ?? 0;
                      smsType = item['type'] as String?;
                    }

                    final normalizedNumber = normalizePhone(number);
                    final contact = contactCache[normalizedNumber];
                    final dateStr = formatDateOnly(ts.toString());
                    final timeStr = formatTimeOnly(ts.toString());

                    IconData iconData;
                    Color iconColor;
                    Widget leadingIconWidget;
                    if (historyType == 'call') {
                      switch ((callType ?? '').toLowerCase()) {
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
                      leadingIconWidget = SizedBox(
                        width: 32,
                        height: 32,
                        child: Center(
                          child: Icon(iconData, color: iconColor, size: 28),
                        ),
                      );
                    } else {
                      leadingIconWidget = smsIconWithMarker(smsType);
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
                          leading: leadingIconWidget,
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
                                    onPressed: () {
                                      _onTapCall(number);
                                    },
                                  ),
                                _buildActionButton(
                                  icon: Icons.message,
                                  color: Colors.blue,
                                  onPressed: () {
                                    _onTapMessage(number);
                                  },
                                ),
                                _buildActionButton(
                                  icon: Icons.search,
                                  color: Colors.orange,
                                  onPressed: () {
                                    _onTapSearch(number);
                                  },
                                ),
                                _buildActionButton(
                                  icon: Icons.edit,
                                  color: Colors.blueGrey,
                                  onPressed: () {
                                    _onTapEdit(number, contact);
                                  },
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
    log(
      '[_RecentCallsScreenState._onTapEdit] Navigating to EditContactScreen for $number',
    );
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => EditContactScreen(
              initialContactId: contact?.contactId,
              initialRawContactId: contact?.rawContactId,
              initialName: contact?.name ?? '',
              initialPhone: normalizePhone(number),
            ),
      ),
    );
    if (result == true) {
      await _refreshHistory();
    }
  }

  Widget smsIconWithMarker(String? smsType) {
    return SizedBox(
      width: 32,
      height: 32,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Center(child: Icon(Icons.sms, color: Colors.grey, size: 28)),
          if (smsType == 'SENT')
            Positioned(
              top: 0,
              right: 0,
              child: CircleAvatar(
                radius: 9,
                backgroundColor: Colors.deepOrange,
                child: Icon(Icons.arrow_upward, color: Colors.white, size: 13),
              ),
            ),
          if (smsType == 'INBOX')
            Positioned(
              top: 0,
              left: 0,
              child: CircleAvatar(
                radius: 9,
                backgroundColor: Colors.green,
                child: Icon(
                  Icons.arrow_downward,
                  color: Colors.white,
                  size: 13,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
