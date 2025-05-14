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
  final Box<Map<String, dynamic>> _contactsBox;

  // Box 이름을 외부에서도 접근 가능하도록 static const 또는 getter로 제공
  static const String boxNameValue = _contactsBoxName;

  @override
  String get boxName => _contactsBoxName;

  HiveContactRepository(this._contactsBox);

  @override
  Future<List<PhoneBookModel>> getAllContacts() async {
    try {
      final List<PhoneBookModel> resultList = [];
      for (final dynamic valueFromBox in _contactsBox.values) {
        if (valueFromBox is Map) {
          final Map<String, dynamic> correctlyTypedMap = valueFromBox.map(
            (key, value) => MapEntry(key.toString(), value),
          );
          // PhoneBookModel.fromJson이 Map<String, dynamic>을 올바르게 처리한다고 가정
          resultList.add(PhoneBookModel.fromJson(correctlyTypedMap));
        } else {
          log(
            '[HiveContactRepository] getAllContacts: Unexpected item type: ${valueFromBox.runtimeType}. Value: $valueFromBox',
          );
        }
      }
      log(
        '[HiveContactRepository] getAllContacts: Successfully fetched ${resultList.length} contacts from Hive.',
      );
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
      // Box를 clear하기 전에 현재 Box가 열려있는지, 유효한지 확인하는 것이 더 안전할 수 있음
      if (!_contactsBox.isOpen) {
        log('[HiveContactRepository] saveContacts: Box is not open!');
        // 필요하다면 여기서 Box를 다시 열거나 예외 처리
        return;
      }
      await _contactsBox.clear();
      final Map<String, Map<String, dynamic>> entriesToPut = {};
      for (final contact in contacts) {
        final String key = contact.contactId;
        // PhoneBookModel.toJson()을 사용하여 Map<String, dynamic>으로 변환
        entriesToPut[key] = contact.toJson();
      }
      if (entriesToPut.isNotEmpty) {
        await _contactsBox.putAll(entriesToPut);
        log(
          '[HiveContactRepository] Saved ${entriesToPut.length} contacts to box: ${_contactsBox.name}',
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
