import 'dart:developer';
import 'package:hive_ce/hive.dart';
import 'package:mobile/models/phone_book_model.dart';

// Hive 박스 이름 정의
const String _contactsBoxName = 'contacts';

/// 연락처 데이터 접근을 위한 추상 클래스 (인터페이스)
abstract class ContactRepository {
  /// 저장된 모든 연락처 목록을 가져옵니다.
  Future<List<PhoneBookModel>> getAllContacts();

  /// 연락처 목록을 저장합니다.
  Future<void> saveContacts(List<PhoneBookModel> contacts);

  /// 모든 연락처 데이터를 삭제합니다 (로그아웃 등에서 사용).
  Future<void> clearContacts();
}

/// Hive를 사용하여 ContactRepository 인터페이스를 구현하는 클래스
class HiveContactRepository implements ContactRepository {
  final Box<Map<String, dynamic>> _contactsBox;

  HiveContactRepository(this._contactsBox);

  @override
  Future<List<PhoneBookModel>> getAllContacts() async {
    try {
      return _contactsBox.values.map((dynamic e) {
        if (e is Map) {
          final map = Map<String, dynamic>.fromEntries(
            (e as Map).entries.map(
              (entry) => MapEntry(entry.key.toString(), entry.value),
            ),
          );
          return PhoneBookModel(
            contactId: map['contactId'] as String? ?? '',
            rawContactId: map['rawContactId'] as String?,
            name: map['name'] as String? ?? '',
            phoneNumber: map['phoneNumber'] as String? ?? '',
            createdAt:
                map['createdAt'] != null
                    ? DateTime.parse(map['createdAt'] as String)
                    : null,
          );
        } else {
          log(
            '[HiveContactRepository] getAllContacts: Unexpected item type: ${e.runtimeType}',
          );
          return PhoneBookModel(contactId: '', name: '', phoneNumber: '');
        }
      }).toList();
    } catch (e) {
      log('[HiveContactRepository] Error getting all contacts: $e');
      return [];
    }
  }

  @override
  Future<void> saveContacts(List<PhoneBookModel> contacts) async {
    try {
      await _contactsBox.clear();
      final Map<String, Map<String, dynamic>> entriesToPut = {};
      for (final contact in contacts) {
        final String key = contact.contactId;
        entriesToPut[key] = {
          'contactId': contact.contactId,
          'rawContactId': contact.rawContactId,
          'name': contact.name,
          'phoneNumber': contact.phoneNumber,
          'createdAt': contact.createdAt?.toIso8601String(),
        };
      }
      if (entriesToPut.isNotEmpty) {
        await _contactsBox.putAll(entriesToPut);
        log('[HiveContactRepository] Saved ${entriesToPut.length} contacts.');
      }
    } catch (e) {
      log('[HiveContactRepository] Error saving contacts: $e');
      rethrow;
    }
  }

  @override
  Future<void> clearContacts() async {
    try {
      await _contactsBox.clear();
      log(
        '[HiveContactRepository] Cleared all contacts from box: ${_contactsBox.name}',
      );
    } catch (e) {
      log('[HiveContactRepository] Error clearing contacts: $e');
    }
  }
}
