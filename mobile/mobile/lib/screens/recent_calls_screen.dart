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
    log('[_RecentCallsScreenState.initState] Called.');
    WidgetsBinding.instance.addObserver(this);
    _checkDefaultDialer();
    _scrollController.addListener(() {
      // 스크롤 관련 로직 로그는 필요시 추가 (현재는 생략)
      // log('[_RecentCallsScreenState] Scroll listener: ${_scrollController.position.pixels}');
    });
    // initState에서 refresh를 호출하는 대신, Provider가 초기 데이터를 로드하도록 유도
    // 만약 즉시 새로고침이 필요하다면 아래 주석 해제
    // WidgetsBinding.instance.addPostFrameCallback((_) {
    //   log('[_RecentCallsScreenState.initState] addPostFrameCallback, calling _refreshHistory.');
    //   _refreshHistory();
    // });
    log('[_RecentCallsScreenState.initState] Finished.');
  }

  @override
  void dispose() {
    log('[_RecentCallsScreenState.dispose] Called.');
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
    super.dispose();
    log('[_RecentCallsScreenState.dispose] Finished.');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    log('[_RecentCallsScreenState.didChangeAppLifecycleState] State: $state');
    if (state == AppLifecycleState.resumed) {
      log(
        '[_RecentCallsScreenState.didChangeAppLifecycleState] App resumed, calling _checkDefaultDialer.',
      );
      _checkDefaultDialer();
      // 앱 재개 시 새로고침이 필요하다면 아래 주석 해제 또는 다른 로직과 연동
      // log('[_RecentCallsScreenState.didChangeAppLifecycleState] App resumed, calling _refreshHistory.');
      // _refreshHistory();
    }
  }

  Future<void> _checkDefaultDialer() async {
    log('[_RecentCallsScreenState._checkDefaultDialer] Started.');
    final isDefault = await NativeDefaultDialerMethods.isDefaultDialer();
    if (!mounted) {
      log(
        '[_RecentCallsScreenState._checkDefaultDialer] Not mounted after await, skipping setState.',
      );
      return;
    }
    setState(() => _isDefaultDialer = isDefault);
    log(
      '[_RecentCallsScreenState._checkDefaultDialer] Finished. isDefaultDialer: $_isDefaultDialer',
    );
  }

  Future<void> _refreshHistory() async {
    log('[_RecentCallsScreenState._refreshHistory] Called.');
    // Provider의 refresh 함수 내부에서 이미 로그가 찍히므로 여기서는 시작/끝만 로깅
    await context.read<RecentHistoryProvider>().refresh();
    log('[_RecentCallsScreenState._refreshHistory] Finished.');
  }

  @override
  Widget build(BuildContext context) {
    log('[_RecentCallsScreenState.build] Called.');

    // Provider.watch를 사용하여 RecentHistoryProvider의 변경사항을 구독
    final recentHistoryProvider = context.watch<RecentHistoryProvider>();
    final recentHistory = recentHistoryProvider.recentHistoryList; // Getter 호출
    log(
      '[_RecentCallsScreenState.build] Watched recentHistoryProvider, list length: ${recentHistory.length}',
    );

    // ContactsController 구독 최적화 (select 사용)
    // select를 사용하면 ContactsController의 특정 필드 변경 시에만 리빌드됨
    final contacts = context.select((ContactsController cc) {
      log(
        '[_RecentCallsScreenState.build] Selecting contacts from ContactsController. Current length: ${cc.contacts.length}',
      );
      return cc.contacts;
    });
    final areContactsLoading = context.select((ContactsController cc) {
      log(
        '[_RecentCallsScreenState.build] Selecting isLoading from ContactsController. Current value: ${cc.isLoading}',
      );
      return cc.isLoading;
    });

    // contactCache는 contacts가 변경될 때만 다시 계산되도록 build 메소드 내부에 둠
    final contactCache = {for (var c in contacts) c.phoneNumber: c};
    log(
      '[_RecentCallsScreenState.build] Created contactCache with ${contactCache.length} entries.',
    );

    // isLoading은 ContactsController의 로딩 상태만 반영 (RecentHistoryProvider의 로딩 상태는 Provider 내부에서 관리)
    final isLoading = areContactsLoading; // 현재는 ContactsController의 로딩만 반영
    // 만약 RecentHistoryProvider 자체의 로딩 상태도 필요하다면, 해당 Provider에 isLoading 상태 추가 필요
    log(
      '[_RecentCallsScreenState.build] isLoading: $isLoading (based on ContactsController)',
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
              onPressed: () {
                log(
                  '[_RecentCallsScreenState.build] Refresh button pressed, calling _refreshHistory.',
                );
                _refreshHistory();
              },
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          log(
            '[_RecentCallsScreenState.build] RefreshIndicator onRefresh triggered, calling _refreshHistory.',
          );
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
                    // itemBuilder 내부 로그는 매우 자주 호출될 수 있으므로 최소화
                    // log('[_RecentCallsScreenState.build] ListView.builder itemBuilder for index $index');
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
                          key: ValueKey(
                            '${number}_$ts',
                          ), // 키를 더 고유하게 (타입 추가 등 고려)
                          isExpanded: index == _expandedIndex,
                          onTap: () {
                            log(
                              '[_RecentCallsScreenState.build] ExpansionTile for index $index tapped. New expandedIndex: ${index == _expandedIndex ? null : index}',
                            );
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
                                      log(
                                        '[_RecentCallsScreenState.build] Call button pressed for $number.',
                                      );
                                      _onTapCall(number);
                                    },
                                  ),
                                _buildActionButton(
                                  icon: Icons.message,
                                  color: Colors.blue,
                                  onPressed: () {
                                    log(
                                      '[_RecentCallsScreenState.build] Message button pressed for $number.',
                                    );
                                    _onTapMessage(number);
                                  },
                                ),
                                _buildActionButton(
                                  icon: Icons.search,
                                  color: Colors.orange,
                                  onPressed: () {
                                    log(
                                      '[_RecentCallsScreenState.build] Search button pressed for $number.',
                                    );
                                    _onTapSearch(number);
                                  },
                                ),
                                _buildActionButton(
                                  icon: Icons.edit,
                                  color: Colors.blueGrey,
                                  onPressed: () {
                                    log(
                                      '[_RecentCallsScreenState.build] Edit button pressed for $number, contact: ${contact?.name}.',
                                    );
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
    // 이 함수는 build 내부에서만 사용되므로 별도 로그는 최소화
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
    log('[_RecentCallsScreenState._onTapMessage] Called for $number.');
    await NativeMethods.openSmsApp(number);
    log('[_RecentCallsScreenState._onTapMessage] Finished for $number.');
  }

  Future<void> _onTapCall(String number) async {
    log('[_RecentCallsScreenState._onTapCall] Called for $number.');
    await NativeMethods.makeCall(number);
    log('[_RecentCallsScreenState._onTapCall] Finished for $number.');
  }

  void _onTapSearch(String number) {
    log(
      '[_RecentCallsScreenState._onTapSearch] Called for $number. Navigating to /search.',
    );
    Navigator.pushNamed(
      context,
      '/search',
      arguments: {'number': number, 'isRequested': false},
    );
  }

  Future<void> _onTapEdit(String number, PhoneBookModel? contact) async {
    log(
      '[_RecentCallsScreenState._onTapEdit] Called for $number. Contact ID: ${contact?.contactId}, Name: ${contact?.name}. Navigating to EditContactScreen.',
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
    log(
      '[_RecentCallsScreenState._onTapEdit] Returned from EditContactScreen with result: $result',
    );
    if (result == true) {
      log(
        '[_RecentCallsScreenState._onTapEdit] EditContactScreen returned true, calling _refreshHistory.',
      );
      await _refreshHistory();
    }
  }

  Widget smsIconWithMarker(String? smsType) {
    // 이 함수는 build 내부에서만 사용되므로 별도 로그는 최소화
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
