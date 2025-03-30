// recent_calls_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mobile/controllers/call_log_controller.dart';
import 'package:mobile/controllers/contacts_controller.dart'; // ContactsController for name lookup
import 'package:mobile/services/native_default_dialer_methods.dart';
import 'package:mobile/utils/app_event_bus.dart';
import 'package:mobile/utils/constants.dart'; // normalizePhone, etc.
import 'package:provider/provider.dart'; // context.read()
import 'package:mobile/models/phone_book_model.dart';
import 'package:mobile/screens/edit_contact_screen.dart';
import 'package:mobile/services/native_methods.dart';
import 'package:mobile/screens/dialer_screen.dart';
import 'package:mobile/widgets/custom_expansion_tile.dart';

class RecentCallsScreen extends StatefulWidget {
  const RecentCallsScreen({super.key});

  @override
  State<RecentCallsScreen> createState() => _RecentCallsScreenState();
}

class _RecentCallsScreenState extends State<RecentCallsScreen>
    with WidgetsBindingObserver {
  final _callLogController = CallLogController();
  bool _isDefaultDialer = false;
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  final _scrollController = ScrollController();
  bool _showSearchField = false;
  int? _expandedIndex;
  double _scrollPosition = 0.0;

  List<Map<String, dynamic>> _callLogs = [];
  StreamSubscription? _eventSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadCalls();
    _checkDefaultDialer();
    _searchFocusNode.addListener(_onFocusChange);
    _scrollController.addListener(() {
      _scrollPosition = _scrollController.position.pixels;
    });
    _eventSub = appEventBus.on<CallLogUpdatedEvent>().listen((event) {
      _loadCalls();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _eventSub?.cancel();
    _searchController.dispose();
    _searchFocusNode.removeListener(_onFocusChange);
    _searchFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // 앱이 다시 전면으로 돌아왔을 때 기본 전화앱 상태 재확인
      _checkDefaultDialer();
    }
  }

  void _onFocusChange() {
    if (!_searchFocusNode.hasFocus && mounted) {
      setState(() {
        _showSearchField = false;
        _searchController.clear();
      });
    }
  }

  Future<void> _loadCalls() async {
    final logs = _callLogController.getSavedCallLogs();
    setState(() {
      _callLogs = logs;
      // 스크롤 위치 복원
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollController.jumpTo(_scrollPosition);
      });
    });
  }

  Future<void> _refreshCalls() async {
    await _callLogController.refreshCallLogs();
    // 로컬DB 반영 뒤 _loadCalls() 재호출
    await _loadCalls();
  }

  Future<void> _checkDefaultDialer() async {
    final isDefault = await NativeDefaultDialerMethods.isDefaultDialer();
    if (!mounted) return;
    setState(() => _isDefaultDialer = isDefault);
  }

  void _toggleSearch() {
    if (_showSearchField) {
      // 검색 실행
      final number = _searchController.text.trim();
      if (number.isNotEmpty) {
        // 액션바에서 직접 검색할 때는 isRequested: true
        Navigator.pushNamed(
          context,
          '/search',
          arguments: {'number': number, 'isRequested': true},
        );
      } else {
        Navigator.pushNamed(context, '/search');
      }
      _searchController.clear();
    }
    setState(() {
      _showSearchField = !_showSearchField;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('최근기록'),
        actions: [
          if (_showSearchField)
            SizedBox(
              width: 150,
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                decoration: InputDecoration(
                  hintText: '번호 입력',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: Colors.grey.shade300,
                      width: 1,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                ),
                keyboardType: TextInputType.phone,
                showCursor: true,
                readOnly: false,
                autofocus: true,
                onSubmitted: (_) => _toggleSearch(),
              ),
            ),
          IconButton(
            icon: Icon(_showSearchField ? Icons.search : Icons.search_outlined),
            onPressed: _toggleSearch,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshCalls,
        child: NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification is ScrollStartNotification) {
              if (_showSearchField) {
                _searchFocusNode.unfocus();
              }
            }
            return false;
          },
          child: ListView.builder(
            controller: _scrollController,
            itemCount: _callLogs.length,
            itemBuilder: (context, index) {
              final call = _callLogs[index];
              final number = call['number'] as String? ?? '';
              final callType = call['callType'] as String? ?? '';
              final ts = call['timestamp'] as int? ?? 0;

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
                      if (_showSearchField) {
                        _searchFocusNode.unfocus();
                      }
                      setState(() {
                        _expandedIndex = index == _expandedIndex ? null : index;
                      });
                    },
                    leading: Icon(iconData, color: iconColor),
                    title: Text(name.isNotEmpty ? name : number),
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
                            onPressed: () => _onTapEdit(number),
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
      ),
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
