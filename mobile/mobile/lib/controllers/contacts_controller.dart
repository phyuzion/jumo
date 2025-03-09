import 'dart:developer';

import 'package:fast_contacts/fast_contacts.dart';
import 'package:get_storage/get_storage.dart';

import 'package:mobile/utils/app_event_bus.dart';

class ContactsController {
  final box = GetStorage();
  static const storageKey = 'fastContacts';

  /// 주소록(이름, 전화번호) 불러오고
  ///  - 전화번호가 없는 연락처는 제외
  ///  - 여러 번호가 있으면 첫 번째 번호만 사용
  ///  - 이름 기준 오름차순 정렬
  ///  - 기존 저장 목록과 비교하여 "새로운/변경된 항목"만 반환
  Future<List<Map<String, dynamic>>> refreshContactsWithDiff() async {
    // 1) 이전 목록
    final oldList = getSavedContacts();
    final oldSet = _buildSetFromList(oldList);

    // 2) fast_contacts
    // 권한(READ_CONTACTS) 승인 필요 (호출 전 Permission.contacts.request() 등)
    final contacts = await FastContacts.getAllContacts();

    final newList = <Map<String, dynamic>>[];

    for (final c in contacts) {
      // c.id (고유ID), c.displayName, c.phones => List<Phone>
      if (c.phones.isEmpty) {
        // 전화번호가 아예 없으면 스킵
        continue;
      }

      final name = c.displayName ?? '';
      // 여러 번호 중 첫 번째 번호만
      final firstPhone = c.phones.first.number;

      // 만약 firstPhone 이 비어있다면 스킵
      if (firstPhone.trim().isEmpty) {
        continue;
      }

      final map = {'id': c.id ?? '', 'name': name, 'phones': firstPhone};
      newList.add(map);
    }

    // (추가) 이름 기준 오름차순 정렬
    // 만약 한글 이름이라면 일반 compareTo 로 충분히 정상 동작할 수 있습니다.
    // 복잡한 정렬 로직이 필요하다면 localeCompare 지원 라이브러리가 필요할 수도 있습니다.
    newList.sort((a, b) {
      final nameA = (a['name'] ?? '') as String;
      final nameB = (b['name'] ?? '') as String;
      return nameA.compareTo(nameB);
    });

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

    // 변경 이벤트
    appEventBus.fire(ContactsUpdatedEvent());

    // 5) 반환 (새/변경 항목)
    return diffList;
  }

  /// 저장된 주소록 읽기
  List<Map<String, dynamic>> getSavedContacts() {
    final list = box.read<List>(storageKey) ?? [];
    return list.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  /// 내부적으로 Map → 고유 문자열 key
  String _makeKey(Map<String, dynamic> m) {
    // "id|name|phones"
    final id = m['id']?.toString() ?? '';
    final name = m['name'] ?? '';
    final ph = m['phones'] ?? '';
    return '$id|$name|$ph';
  }

  /// 목록 → Set<String> 변환
  Set<String> _buildSetFromList(List<Map<String, dynamic>> list) {
    return list.map((m) => _makeKey(m)).toSet();
  }
}
