import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:mobile/controllers/contacts_controller.dart';
import 'package:mobile/models/phone_book_model.dart';
import 'package:mobile/screens/edit_contact_screen.dart';
import 'package:mobile/services/native_methods.dart';
import 'package:mobile/utils/app_event_bus.dart';
import 'package:mobile/widgets/dropdown_menus_widet.dart';
import 'package:provider/provider.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  List<PhoneBookModel> _contacts = [];
  StreamSubscription? _eventSub;

  // 검색 모드 On/Off
  bool _isSearching = false;
  // 검색어
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadContacts();
    _eventSub = appEventBus.on<ContactsUpdatedEvent>().listen((event) {
      _loadContacts();
    });
  }

  @override
  void dispose() {
    _eventSub?.cancel();
    super.dispose();
  }

  Future<void> _loadContacts() async {
    final contactsCtrl = context.read<ContactsController>();
    final list = contactsCtrl.getSavedContacts();

    if (!mounted) return;
    setState(() => _contacts = list);
  }

  Future<void> _refreshContacts() async {
    final contactsCtrl = context.read<ContactsController>();
    await contactsCtrl.syncContactsAll();
    await _loadContacts();
  }

  /// ==========================
  /// 필터링된 리스트 반환
  /// ==========================
  List<PhoneBookModel> get _filteredContacts {
    if (_searchQuery.isEmpty) {
      return _contacts; // 검색어가 없으면 전체 보여주기
    }
    final lowerQuery = _searchQuery.toLowerCase();
    return _contacts.where((c) {
      final name = c.name.toLowerCase();
      final phone = c.phoneNumber.toLowerCase();
      return name.contains(lowerQuery) || phone.contains(lowerQuery);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final data = _filteredContacts;

    return Scaffold(
      appBar: AppBar(
        title: _buildAppBarTitle(),
        actions: _buildAppBarActions(),
      ),
      body: RefreshIndicator(
        onRefresh: _refreshContacts,
        child: ListView.separated(
          itemCount: data.length,
          separatorBuilder:
              (ctx, i) => const Divider(
                color: Colors.grey,
                thickness: 0.5,
                indent: 16.0,
                endIndent: 16.0,
                height: 0,
              ),
          itemBuilder: (ctx, i) {
            final c = data[i];
            final name = c.name;
            final phone = c.phoneNumber;
            final memo = c.memo ?? '';
            final firstChar = name.isNotEmpty ? name.characters.first : '?';

            return Slidable(
              key: ValueKey(i),
              endActionPane: ActionPane(
                motion: const BehindMotion(),
                children: [
                  SlidableAction(
                    onPressed: (_) => _onTapCall(phone),
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    icon: Icons.call,
                  ),
                  SlidableAction(
                    onPressed: (_) => _onTapSearch(phone),
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    icon: Icons.search,
                  ),
                  SlidableAction(
                    onPressed: (_) => _onTapEdit(c),
                    backgroundColor: Colors.blueGrey,
                    foregroundColor: Colors.white,
                    icon: Icons.edit,
                  ),
                ],
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                leading: CircleAvatar(
                  radius: 16,
                  backgroundColor: _pickColorFromChar(firstChar),
                  child: Text(
                    firstChar,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                title: Text(
                  name.isNotEmpty ? name : '이름 없음',
                  style: const TextStyle(fontSize: 16),
                ),
                subtitle: Text(
                  phone + (memo.isNotEmpty ? ' / $memo' : ''),
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _onTapAddContact,
        child: const Icon(Icons.add),
      ),
    );
  }

  /// ===============================
  /// AppBar Title 영역
  /// ===============================
  Widget _buildAppBarTitle() {
    if (_isSearching) {
      // 검색 모드일 때 -> TextField 보여줌
      return TextField(
        autofocus: true, // AppBar 열리면 자동 포커스
        decoration: const InputDecoration(
          hintText: '검색어 입력',
          border: InputBorder.none,
        ),
        onChanged: (value) {
          setState(() => _searchQuery = value);
        },
        style: const TextStyle(color: Colors.black, fontSize: 22),
      );
    } else {
      // 일반 모드일 때 -> 제목
      return const Text('연락처');
    }
  }

  /// ===============================
  /// AppBar Actions
  /// ===============================
  List<Widget> _buildAppBarActions() {
    if (_isSearching) {
      // 검색 모드일 때 => "닫기" 아이콘
      return [
        IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            setState(() {
              _isSearching = false;
              _searchQuery = '';
            });
          },
        ),
        // 드롭다운 메뉴
        const DropdownMenusWidget(),
      ];
    } else {
      // 일반 모드 => "검색" 아이콘
      return [
        IconButton(
          icon: const Icon(Icons.search),
          onPressed: () {
            setState(() => _isSearching = true);
          },
        ),
        // 드롭다운 메뉴
        const DropdownMenusWidget(),
      ];
    }
  }

  Future<void> _onTapCall(String phoneNumber) async {
    await NativeMethods.makeCall(phoneNumber);
    // if (await NativeDefaultDialerMethods.isDefaultDialer()) {
    //   Navigator.of(context).pushNamed('/onCall', arguments: phoneNumber);
    // }
  }

  void _onTapSearch(String phone) {
    Navigator.pushNamed(context, '/search', arguments: phone);
  }

  Future<void> _onTapEdit(PhoneBookModel model) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => EditContactScreen(
              initialContactId: model.contactId,
              initialName: model.name,
              initialPhone: model.phoneNumber,
              initialMemo: model.memo,
              initialType: model.type,
            ),
      ),
    );
  }

  Future<void> _onTapAddContact() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const EditContactScreen()),
    );
    if (result == true) {
      await _refreshContacts();
    }
  }

  Color _pickColorFromChar(String char) {
    final code = char.toUpperCase().codeUnitAt(0);
    final hue = (code * 5) % 360;
    return HSLColor.fromAHSL(1.0, hue.toDouble(), 0.6, 0.7).toColor();
  }
}
