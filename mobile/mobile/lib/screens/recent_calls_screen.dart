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
import 'package:mobile/screens/dialer_screen.dart';
import 'package:mobile/widgets/custom_expansion_tile.dart';
import 'dart:developer';
import 'package:mobile/utils/app_event_bus.dart'; // 복구

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
  bool _isLoading = true;
  List<Map<String, dynamic>> _callLogs = [];
  Map<String, PhoneBookModel> _contactInfoCache = {};
  StreamSubscription? _callLogUpdateSub;

  @override
  void initState() {
    super.initState();
    log('[RecentCallsScreen] initState called.');
    WidgetsBinding.instance.addObserver(this);
    _loadCallsAndContacts();
    _checkDefaultDialer();
    _scrollController.addListener(() {
      /* ... */
    });

    _callLogUpdateSub = appEventBus.on<CallLogUpdatedEvent>().listen((_) {
      log('[RecentCallsScreen] Received CallLogUpdatedEvent.');
      if (mounted) {
        log(
          '[RecentCallsScreen] Widget is mounted, calling _loadCallsAndContacts...',
        );
        _loadCallsAndContacts();
      } else {
        log(
          '[RecentCallsScreen] Warning: Widget not mounted when receiving event.',
        );
      }
    });
    log('[RecentCallsScreen] Subscribed to CallLogUpdatedEvent.');
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _callLogUpdateSub?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _checkDefaultDialer();
      _loadCallsAndContacts();
    }
  }

  Future<void> _checkDefaultDialer() async {
    final isDefault = await NativeDefaultDialerMethods.isDefaultDialer();
    if (!mounted) return;
    setState(() => _isDefaultDialer = isDefault);
  }

  Future<void> _loadCallsAndContacts() async {
    final stopwatch = Stopwatch()..start();
    log('[RecentCallsScreen] _loadCallsAndContacts started.');
    if (!mounted) {
      return;
    }
    if (!_isLoading) {
      setState(() => _isLoading = true);
    } else {
      log('[RecentCallsScreen] Already loading.');
    }

    try {
      final contactsCtrl = context.read<ContactsController>();
      final callLogCtrl = context.read<CallLogController>();

      final logs = callLogCtrl.getSavedCallLogs();
      final contacts = await contactsCtrl.getLocalContacts();

      if (!mounted) {
        stopwatch.stop();
        return;
      }

      _contactInfoCache = {for (var c in contacts) c.phoneNumber: c};

      setState(() {
        _callLogs = logs;
        _isLoading = false;
      });
    } catch (e, st) {
      log('[RecentCallsScreen] Error loading calls and contacts: $e\n$st');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('최근 기록을 불러오는데 실패했습니다.')));
      }
    } finally {
      stopwatch.stop();
      log(
        '[RecentCallsScreen] _loadCallsAndContacts finished in ${stopwatch.elapsedMilliseconds}ms',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    log('[RecentCallsScreen] build called.');
    final data = _callLogs;

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
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : data.isEmpty
                ? Center(child: Text('최근 통화 기록이 없습니다.'))
                : ListView.builder(
                  controller: _scrollController,
                  itemCount: data.length,
                  itemBuilder: (context, index) {
                    final call = data[index];
                    final number = call['number'] as String? ?? '';
                    final callType = call['callType'] as String? ?? '';
                    final ts = call['timestamp'] as int? ?? 0;

                    final normalizedNumber = normalizePhone(number);
                    final contact = _contactInfoCache[normalizedNumber];

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

  Future<void> _refreshCalls() async {
    context.read<ContactsController>().invalidateCache();
    await context.read<CallLogController>().refreshCallLogs();
  }
}
