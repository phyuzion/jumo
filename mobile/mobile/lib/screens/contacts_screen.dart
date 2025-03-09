import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:mobile/services/native_methods.dart';

import '../controllers/contacts_controller.dart';
import '../utils/app_event_bus.dart'; // EventBus, ContactsUpdatedEvent

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final _contactsController = ContactsController();
  List<Map<String, dynamic>> _contacts = [];

  StreamSubscription? _eventSub;

  @override
  void initState() {
    super.initState();
    _loadContacts();

    // 주소록 변경 이벤트 => 재로드
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
    final list = _contactsController.getSavedContacts();
    setState(() => _contacts = list);
  }

  Future<void> _refreshContacts() async {
    await _contactsController.refreshContactsMerged();
    await _loadContacts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 상단 AppBar 는 HomeScreen(탭) 쪽에서 처리
      body: RefreshIndicator(
        onRefresh: _refreshContacts,
        child: ListView.builder(
          itemCount: _contacts.length,
          itemBuilder: (ctx, i) {
            final c = _contacts[i];
            final name = c['name'] as String? ?? '';
            final phones = c['phones'] as String? ?? '';

            // 첫글자(아바타 색상 결정)
            final firstChar = name.isNotEmpty ? name.characters.first : '?';
            final avatarColor = _pickColorFromChar(firstChar);

            return Slidable(
              key: ValueKey(i),
              endActionPane: ActionPane(
                motion: const BehindMotion(),
                children: [
                  // 통화 아이콘
                  SlidableAction(
                    onPressed: (_) => _onTapCall(name, phones),
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    icon: Icons.call,
                  ),
                  // 검색 아이콘
                  SlidableAction(
                    onPressed: (_) => _onTapSearch(name, phones),
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    icon: Icons.search,
                  ),
                  // 편집 아이콘
                  SlidableAction(
                    onPressed: (_) => _onTapEdit(name, phones),
                    backgroundColor: Colors.blueGrey,
                    foregroundColor: Colors.white,
                    icon: Icons.edit,
                  ),
                ],
              ),
              child: Container(
                height: 70,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    // 왼쪽 원형 아바타
                    CircleAvatar(
                      backgroundColor: avatarColor,
                      radius: 22,
                      child: Text(
                        firstChar,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // 이름 + 번호
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 이름(또는 ???)
                          Text(
                            name.isNotEmpty ? name : '이름 없음',
                            style: const TextStyle(fontSize: 18),
                          ),
                          // 번호
                          Text(
                            phones,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // 여기 trailing 아이콘 넣을 수도 있음, 현재는 없음
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// 간단: 첫글자로부터 Hue값 만들어 파스텔색
  Color _pickColorFromChar(String char) {
    final code = char.toUpperCase().codeUnitAt(0);
    final hue = (code * 5) % 360;
    return HSLColor.fromAHSL(1.0, hue.toDouble(), 0.6, 0.7).toColor();
  }

  // 슬라이드 액션 로직
  void _onTapCall(String name, String phones) {
    NativeMethods.makeCall(phones.split(',')[0]);
    debugPrint('[Contacts] Tap Call => $name / $phones');
  }

  void _onTapSearch(String name, String phones) {
    Navigator.pushNamed(context, '/search', arguments: phones);
    debugPrint('[Contacts] Tap Search => $name / $phones');
  }

  void _onTapEdit(String name, String phones) {
    debugPrint('[Contacts] Tap Edit => $name / $phones');
  }
}
