// lib/screens/contacts_screen.dart
import 'package:flutter/material.dart';

class ContactsScreen extends StatelessWidget {
  const ContactsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // "연락처 300개"
    // 간단 ListView
    return ListView.builder(
      itemCount: 30, // demo
      itemBuilder: (ctx, i) {
        return ListTile(
          leading: CircleAvatar(
            child: Text('A'), // 첫글자
          ),
          title: Text('이름 $i'),
          subtitle: Text('010-xxxx-xxxx'),
        );
      },
    );
  }
}
