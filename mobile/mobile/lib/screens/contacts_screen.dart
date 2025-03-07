import 'package:flutter/material.dart';
import 'dart:async';
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

    // EventBus 수신 => 주소록 변경 시 onContactsUpdated
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

  /// 새로고침
  Future<void> _refreshContacts() async {
    // Diff 로직
    await _contactsController.refreshContactsWithDiff();
    // 끝나면 _loadContacts() -> setState
    _loadContacts();
  }

  @override
  Widget build(BuildContext context) {
    // 하단 BottomNavigationBar는 HomeScreen(메인)에서 관리한다면,
    // 여기서는 body 부분만 구현
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _refreshContacts,
        child: ListView.builder(
          itemCount: _contacts.length,
          itemBuilder: (ctx, i) {
            final c = _contacts[i];
            final name = c['name'] as String? ?? '';
            final phones = c['phones'] as String? ?? '';

            // 첫글자(원형 아바타에 표시)
            final firstChar = name.isNotEmpty ? name.characters.first : '?';

            // 원형 배경색 (간단히, 첫글자에 따라 결정 or 무작위)
            final avatarColor = _pickColorFromChar(firstChar);

            return ListTile(
              leading: CircleAvatar(
                backgroundColor: avatarColor,
                child: Text(
                  firstChar,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              title: Text(name, style: const TextStyle(fontSize: 16)),
              subtitle: Text(phones), // 여러 번호를 ','로 합쳐둔 것
              // onTap 시 전화, 상세보기 등 가능
              onTap: () {
                // 예) 상세 페이지 이동?
              },
            );
          },
        ),
      ),
    );
  }

  /// 단순: 첫글자에 따라 파스텔 색상을 뽑는 함수 (예시)
  Color _pickColorFromChar(String char) {
    // A ~ Z 등등을 int로 변환
    final code = char.toUpperCase().codeUnitAt(0);
    // 임의로 hue 를 code 에서 뽑고, saturation/value 고정
    final hue = (code * 5) % 360;
    return HSLColor.fromAHSL(1.0, hue.toDouble(), 0.6, 0.7).toColor();
  }
}
