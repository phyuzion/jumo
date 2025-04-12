import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mobile/controllers/contacts_controller.dart';
import 'package:mobile/models/phone_book_model.dart';
import 'package:mobile/screens/edit_contact_screen.dart';
import 'package:mobile/services/native_methods.dart';
import 'package:mobile/services/native_default_dialer_methods.dart';
import 'package:mobile/widgets/custom_expansion_tile.dart';
import 'package:provider/provider.dart';
import 'dart:developer';
import 'package:flutter/foundation.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:hive_ce/hive.dart';
import 'package:mobile/utils/constants.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  int? _expandedIndex;
  bool _isDefaultDialer = false;
  bool _isSearching = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _checkDefaultDialer();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _checkDefaultDialer() async {
    final isDefault = await NativeDefaultDialerMethods.isDefaultDialer();
    if (!mounted) return;
    setState(() => _isDefaultDialer = isDefault);
  }

  Future<void> _refreshContacts() async {
    await context.read<ContactsController>().getLocalContacts(
      forceRefresh: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final contactsProvider = context.watch<ContactsController>();
    final allContacts = contactsProvider.contacts;
    final isLoading = contactsProvider.isLoading;

    final List<PhoneBookModel> data;
    if (_searchQuery.isEmpty) {
      data = allContacts;
    } else {
      final lowerQuery = _searchQuery.toLowerCase();
      data =
          allContacts.where((c) {
            final name = c.name.toLowerCase();
            final phone = c.phoneNumber.toLowerCase();
            return name.contains(lowerQuery) || phone.contains(lowerQuery);
          }).toList();
    }
    log(
      '[ContactsScreen] build: isLoading=$isLoading, contact count: ${data.length}',
    );

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(40),
        child: AppBar(
          title:
              _isSearching
                  ? TextField(
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: '검색어 입력',
                      border: InputBorder.none,
                    ),
                    onChanged: (value) {
                      setState(() => _searchQuery = value);
                    },
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  )
                  : const Text(
                    '연락처',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
          actions: [
            IconButton(
              icon: Icon(_isSearching ? Icons.close : Icons.search, size: 24),
              onPressed: () {
                setState(() {
                  _isSearching = !_isSearching;
                  if (!_isSearching) _searchQuery = '';
                });
              },
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refreshContacts,
        child:
            isLoading
                ? const Center(child: CircularProgressIndicator())
                : data.isEmpty
                ? Center(
                  child: Text(
                    _searchQuery.isEmpty ? '연락처가 없습니다.' : '검색 결과가 없습니다.',
                  ),
                )
                : ListView.builder(
                  itemCount: data.length,
                  itemBuilder: (ctx, i) {
                    final c = data[i];
                    final name = c.name;
                    final phone = c.phoneNumber;
                    final firstChar =
                        name.isNotEmpty ? name.characters.first : '?';

                    return Column(
                      children: [
                        if (i > 0)
                          const Divider(
                            color: Colors.grey,
                            thickness: 0.5,
                            indent: 16.0,
                            endIndent: 16.0,
                            height: 0,
                          ),
                        CustomExpansionTile(
                          key: ValueKey('${phone}_$i'),
                          isExpanded: i == _expandedIndex,
                          onTap: () {
                            setState(() {
                              _expandedIndex = i == _expandedIndex ? null : i;
                            });
                          },
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
                            phone,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
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
                                    onPressed: () => _onTapCall(phone),
                                  ),
                                _buildActionButton(
                                  icon: Icons.message,
                                  color: Colors.blue,
                                  onPressed: () => _onTapMessage(phone),
                                ),
                                _buildActionButton(
                                  icon: Icons.search,
                                  color: Colors.orange,
                                  onPressed: () => _onTapSearch(phone),
                                ),
                                _buildActionButton(
                                  icon: Icons.edit,
                                  color: Colors.blueGrey,
                                  onPressed: () => _onTapEdit(c),
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
      floatingActionButton: FloatingActionButton(
        onPressed: _onTapAddContact,
        child: const Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
    );
  }

  Future<void> _onTapMessage(String phoneNumber) async {
    await NativeMethods.openSmsApp(phoneNumber);
  }

  Future<void> _onTapCall(String phoneNumber) async {
    await NativeMethods.makeCall(phoneNumber);
  }

  void _onTapSearch(String phone) {
    Navigator.pushNamed(context, '/search', arguments: phone);
  }

  Future<void> _onTapEdit(PhoneBookModel model) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => EditContactScreen(
              initialContactId: model.contactId,
              initialName: model.name,
              initialPhone: model.phoneNumber,
            ),
      ),
    );
    if (result == true) {
      await _refreshContacts();
    }
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
}
