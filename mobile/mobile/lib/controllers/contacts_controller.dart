// lib/controllers/contacts_controller.dart
import 'dart:developer';

import 'package:fast_contacts/fast_contacts.dart';
import 'package:get_storage/get_storage.dart';

class ContactsController {
  final box = GetStorage();
  static const storageKey = 'fastContacts';

  /// 주소록(이름, 전화번호) 불러오고 -> 기존과 비교 -> 새 항목만 반환
  Future<List<Map<String, dynamic>>> refreshContactsWithDiff() async {
    // 1) 이전 목록
    final oldList = getSavedContacts();
    final oldSet = _buildSetFromList(oldList);
    // 2) fast_contacts
    // 권한(READ_CONTACTS) 승인 필요
    // await Permission.contacts.request();
    final contacts = await FastContacts.getAllContacts();

    final newList = <Map<String, dynamic>>[];
    for (final c in contacts) {
      // c.id (고유ID), c.displayName, c.phones => List<Phone>
      final name = c.displayName ?? '';
      // 전화번호 여러개 => ','로 합침
      final phoneStr = c.phones.map((ph) => ph.number).join(',');

      final map = {
        'id': c.id ?? '', // optional
        'name': name ?? '',
        'phones': phoneStr ?? '',
      };
      newList.add(map);
    }

    // 3) set
    final newSet = _buildSetFromList(newList);
    final diffKeys = newSet.difference(oldSet);

    final diffList =
        newList.where((m) {
          final key = _makeKey(m);
          return diffKeys.contains(key);
        }).toList();

    // 4) 저장
    await box.write(storageKey, newList);

    // 5) 반환
    return diffList;
  }

  List<Map<String, dynamic>> getSavedContacts() {
    final list = box.read<List>(storageKey) ?? [];
    return list.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  String _makeKey(Map<String, dynamic> m) {
    // "id|name|phones"
    final id = m['id']?.toString() ?? '';
    final name = m['name'] ?? '';
    final ph = m['phones'] ?? '';
    return '$id|$name|$ph';
  }

  Set<String> _buildSetFromList(List<Map<String, dynamic>> list) {
    return list.map((m) => _makeKey(m)).toSet();
  }
}
