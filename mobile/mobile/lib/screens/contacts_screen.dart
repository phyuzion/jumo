// lib/screens/contacts_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:mobile/controllers/contacts_controller.dart';
import 'package:mobile/models/phone_book_model.dart';
import 'package:mobile/screens/edit_contact_screen.dart';
import 'package:mobile/services/native_methods.dart';
import 'package:mobile/utils/app_event_bus.dart';
import 'package:provider/provider.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  List<PhoneBookModel> _contacts = [];
  StreamSubscription? _eventSub;

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
    setState(() => _contacts = list);
  }

  Future<void> _refreshContacts() async {
    final contactsCtrl = context.read<ContactsController>();
    await contactsCtrl.syncContactsAll();
    await _loadContacts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _refreshContacts,
        child: ListView.builder(
          itemCount: _contacts.length,
          itemBuilder: (ctx, i) {
            final c = _contacts[i];
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
                leading: CircleAvatar(
                  backgroundColor: _pickColorFromChar(firstChar),
                  child: Text(
                    firstChar,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                title: Text(
                  name.isNotEmpty ? name : '이름 없음',
                  style: const TextStyle(fontSize: 18),
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

  Future<void> _onTapCall(String phoneNumber) async {
    await NativeMethods.makeCall(phoneNumber);
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
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const EditContactScreen()),
    );
  }

  Color _pickColorFromChar(String char) {
    final code = char.toUpperCase().codeUnitAt(0);
    final hue = (code * 5) % 360;
    return HSLColor.fromAHSL(1.0, hue.toDouble(), 0.6, 0.7).toColor();
  }
}
