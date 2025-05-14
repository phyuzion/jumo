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

  String get boxName; // Box 이름을 외부에서 알 수 있도록 getter 추가
}

/// Hive를 사용하여 ContactRepository 인터페이스를 구현하는 클래스
class HiveContactRepository implements ContactRepository {
  final Box<Map<dynamic, dynamic>> _contactsBox;

  // Box 이름을 외부에서도 접근 가능하도록 static const 또는 getter로 제공
  static const String boxNameValue = _contactsBoxName;

  @override
  String get boxName => _contactsBoxName;

  HiveContactRepository(this._contactsBox);

  @override
  Future<List<PhoneBookModel>> getAllContacts() async {
    try {
      final List<PhoneBookModel> resultList = [];
      for (final dynamic valueFromBoxDynamic in _contactsBox.values) {
        if (valueFromBoxDynamic is Map) {
          try {
            // Map<dynamic, dynamic>을 Map<String, dynamic>으로 변환
            final Map<String, dynamic> correctlyTypedMap = valueFromBoxDynamic
                .map((key, value) => MapEntry(key.toString(), value));
            resultList.add(PhoneBookModel.fromJson(correctlyTypedMap));
          } catch (conversionError) {
            log(
              '[HiveContactRepository] Error converting map to PhoneBookModel: $conversionError. Map: $valueFromBoxDynamic',
            );
          }
        } else {
          log(
            '[HiveContactRepository] getAllContacts: Unexpected item type: ${valueFromBoxDynamic.runtimeType}. Value: $valueFromBoxDynamic',
          );
        }
      }
      return resultList;
    } catch (e, s) {
      log(
        '[HiveContactRepository] Error getting all contacts: $e',
        stackTrace: s,
      );
      return [];
    }
  }

  @override
  Future<void> saveContacts(List<PhoneBookModel> contacts) async {
    try {
      if (!_contactsBox.isOpen) {
        log('[HiveContactRepository] saveContacts: Box is not open!');
        return;
      }
      await _contactsBox.clear();
      // 저장하는 값은 여전히 Map<String, dynamic>이지만, Box의 값 타입은 Map<dynamic, dynamic>으로 넓혀짐
      final Map<String, Map<String, dynamic>> entriesToPut = {};
      for (final contact in contacts) {
        final String key = contact.contactId;
        entriesToPut[key] =
            contact.toJson(); // toJson()은 Map<String, dynamic> 반환
      }
      if (entriesToPut.isNotEmpty) {
        // putAll의 값 타입이 Box의 값 타입과 일치하거나 호환되어야 함.
        // Map<String, Map<String, dynamic>>을 Box<Map<dynamic, dynamic>>에 넣음.
        // 각 Map<String, dynamic>은 Map<dynamic, dynamic>으로 암시적 변환 가능.
        await _contactsBox.putAll(
          entriesToPut.cast<String, Map<dynamic, dynamic>>(),
        );
      } else {
        log(
          '[HiveContactRepository] No contacts to save to box: ${_contactsBox.name}',
        );
      }
    } catch (e, s) {
      log('[HiveContactRepository] Error saving contacts: $e', stackTrace: s);
      rethrow;
    }
  }

  @override
  Future<void> clearContacts() async {
    try {
      if (!_contactsBox.isOpen) {
        log('[HiveContactRepository] clearContacts: Box is not open!');
        return;
      }
      await _contactsBox.clear();
      log(
        '[HiveContactRepository] Cleared all contacts from box: ${_contactsBox.name}',
      );
    } catch (e, s) {
      log('[HiveContactRepository] Error clearing contacts: $e', stackTrace: s);
    }
  }
}
