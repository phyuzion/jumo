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
  final _callLogController = CallLogController();
  bool _isDefaultDialer = false;
  final _scrollController = ScrollController();
  int? _expandedIndex;
  bool _isLoading = true; // 로딩 상태 추가

  List<Map<String, dynamic>> _callLogs = [];
  // 연락처 정보 캐시 (Key: 정규화된 전화번호)
  Map<String, PhoneBookModel> _contactInfoCache = {};
  StreamSubscription? _callLogUpdateSub; // 이벤트 구독 변수

  @override
  void initState() {
    super.initState();
    log('[RecentCallsScreen] initState called.'); // initState 시작 로그
    WidgetsBinding.instance.addObserver(this);
    _loadCallsAndContacts(); // 초기 로드
    _checkDefaultDialer();
    _scrollController.addListener(() {
      /* ... */
    });

    // CallLogUpdatedEvent 구독
    _callLogUpdateSub = appEventBus.on<CallLogUpdatedEvent>().listen((_) {
      // ***** 이벤트 수신 로그 *****
      log('[RecentCallsScreen] Received CallLogUpdatedEvent.');
      if (mounted) {
        log(
          '[RecentCallsScreen] Widget is mounted, calling _loadCallsAndContacts...',
        );
        _loadCallsAndContacts(); // 데이터 다시 로드
      } else {
        log(
          '[RecentCallsScreen] Warning: Widget not mounted when receiving event.',
        );
      }
    });
    log('[RecentCallsScreen] Subscribed to CallLogUpdatedEvent.'); // 구독 완료 로그
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _callLogUpdateSub?.cancel(); // 구독 해제
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _checkDefaultDialer();
      // 포그라운드 복귀 시 데이터 다시 로드
      _loadCallsAndContacts();
    }
  }

  // 통화기록과 연락처 정보를 함께 로드
  Future<void> _loadCallsAndContacts() async {
    final stopwatch = Stopwatch()..start(); // 전체 함수 시간 측정
    log('[RecentCallsScreen] _loadCallsAndContacts started.');
    if (!mounted) {
      log(
        '[RecentCallsScreen] _loadCallsAndContacts: Widget not mounted at start, aborting.',
      );
      return;
    }
    // 로딩 상태 변경 (이미 로딩 중이면 로그만 남김)
    if (!_isLoading) {
      setState(() {
        _isLoading = true;
      });
    } else {
      log(
        '[RecentCallsScreen] _loadCallsAndContacts: Already in loading state.',
      );
    }

    try {
      final contactsCtrl = context.read<ContactsController>();
      final callLogCtrl = context.read<CallLogController>();

      // 1. 통화 기록 로드 (Hive - 동기)
      final stepwatch = Stopwatch()..start();
      log('[RecentCallsScreen] Loading call logs from Hive...');
      final logs = callLogCtrl.getSavedCallLogs();
      stepwatch.stop();
      log(
        '[RecentCallsScreen] Loaded ${logs.length} call logs from Hive in ${stepwatch.elapsedMilliseconds}ms.',
      );
      stepwatch.reset();

      // 2. 연락처 정보 로드 (비동기)
      log('[RecentCallsScreen] Loading local contacts...');
      stepwatch.start();
      final contacts = await contactsCtrl.getLocalContacts();
      stepwatch.stop();
      log(
        '[RecentCallsScreen] Loaded ${contacts.length} contacts in ${stepwatch.elapsedMilliseconds}ms.',
      );
      stepwatch.reset();

      // 3. 연락처 정보 캐시 업데이트
      log('[RecentCallsScreen] Updating contact cache...');
      stepwatch.start();
      _contactInfoCache = {for (var c in contacts) c.phoneNumber: c};
      stepwatch.stop();
      log(
        '[RecentCallsScreen] Updated contact cache in ${stepwatch.elapsedMilliseconds}ms.',
      );

      // 비동기 작업 후 마운트 상태 재확인
      if (!mounted) {
        log(
          '[RecentCallsScreen] _loadCallsAndContacts: Widget not mounted after async operations.',
        );
        stopwatch.stop(); // 함수 종료 전 시간 측정 중지
        return;
      }

      log('[RecentCallsScreen] Calling setState with ${logs.length} logs...');
      setState(() {
        _callLogs = logs;
        _isLoading = false;
      });
      log(
        '[RecentCallsScreen] setState finished. _callLogs length is now: ${_callLogs.length}',
      ); // setState 후 상태 확인 로그
    } catch (e, st) {
      log('[RecentCallsScreen] Error loading calls and contacts: $e\n$st');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('최근 기록을 불러오는데 실패했습니다.')));
      }
    } finally {
      stopwatch.stop(); // finally 블록으로 이동
      log(
        '[RecentCallsScreen] _loadCallsAndContacts finished in ${stopwatch.elapsedMilliseconds}ms.',
      );
    }
  }

  // 새로고침 시 통화기록 갱신 후 다시 로드
  Future<void> _refreshCalls() async {
    // ***** 캐시 초기화 추가 *****
    context.read<ContactsController>().invalidateCache();
    await _callLogController.refreshCallLogs(); // 통화 기록 갱신
    await _loadCallsAndContacts(); // 최신 연락처 포함하여 로드
  }

  Future<void> _checkDefaultDialer() async {
    final isDefault = await NativeDefaultDialerMethods.isDefaultDialer();
    if (!mounted) return;
    setState(() => _isDefaultDialer = isDefault);
  }

  @override
  Widget build(BuildContext context) {
    // ***** build 메소드 호출 로그 추가 *****
    log(
      '[RecentCallsScreen] build called. _isLoading: $_isLoading, _callLogs count: ${_callLogs.length}',
    );

    final data = _callLogs; // 필터링된 데이터 사용 확인
    log('[RecentCallsScreen] build: filtered data count: ${data.length}');

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(40),
        child: AppBar(
          title: const Text(
            // const 추가
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
                : ListView.builder(
                  controller: _scrollController,
                  // ***** itemCount 로그 추가 *****
                  itemCount: data.length, // itemCount 확인
                  itemBuilder: (context, index) {
                    final call = data[index];
                    final number = call['number'] as String? ?? '';
                    final callType = call['callType'] as String? ?? '';
                    final ts = call['timestamp'] as int? ?? 0;
                    // final contact = call['contact'] as PhoneBookModel?; // 이전 방식 제거

                    // 캐시에서 연락처 정보 조회 (정규화된 번호 사용)
                    final normalizedNumber = normalizePhone(number);
                    final contact = _contactInfoCache[normalizedNumber];

                    // === 날짜/시간 표시
                    final dateStr = formatDateOnly(ts.toString());
                    final timeStr = formatTimeOnly(ts.toString());

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

                    // 이름 표시: 연락처 이름 우선, 없으면 번호
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
                          title: Text(displayName), // 이름 표시
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
                                  // 편집 화면으로 이동 시 연락처 정보 전달
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
      // <<< FAB 정의 제거 시작 >>>
      /* 
      floatingActionButton:
          _isDefaultDialer
              ? FloatingActionButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const DialerScreen(),
                    ),
                  );
                },
                child: const Icon(Icons.dialpad),
              )
              : null, 
      */
      // <<< FAB 정의 제거 끝 >>>
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
    // 리스트에서 검색 버튼 클릭시에는 isRequested: false
    Navigator.pushNamed(
      context,
      '/search',
      arguments: {'number': number, 'isRequested': false},
    );
  }

  // 편집 버튼 클릭 시
  Future<void> _onTapEdit(String number, PhoneBookModel? contact) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => EditContactScreen(
              // 연락처 ID, 이름, 정규화된 번호 전달
              initialContactId: contact?.contactId,
              initialName: contact?.name ?? '', // 캐시된 이름 사용
              initialPhone: normalizePhone(number), // 항상 정규화된 번호 전달
              // initialMemo, initialType은 전달 안 함
            ),
      ),
    );
    // 수정/추가 완료 후 돌아왔을 때 목록 새로고침
    if (result == true) {
      await _refreshCalls(); // 통화기록 & 연락처 다시 로드
    }
  }
}
