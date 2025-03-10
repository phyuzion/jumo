import 'dart:convert';
import 'dart:developer';

import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:get_storage/get_storage.dart';
import 'package:mobile/graphql/phone_records_api.dart';
import 'package:mobile/models/phone_book_model.dart';
import 'package:mobile/utils/app_event_bus.dart';
import 'package:mobile/utils/constants.dart';

class ContactsController {
  final box = GetStorage();
  static const storageKey = 'phonebook';

  /// 1) 디바이스 주소록과 로컬 phonebook 병합
  Future<void> refreshContactsWithDiff() async {
    final oldList = _getLocalPhoneBook();
    final oldMap = <String, PhoneBookModel>{
      for (var o in oldList) o.phoneNumber: o,
    };

    // flutter_contacts 로 주소록 읽기
    final deviceContacts = await FlutterContacts.getContacts(
      withProperties: true,
      withAccounts: true,
    );
    final deviceList = <PhoneBookModel>[];

    for (final c in deviceContacts) {
      // flutter_contacts 의 Contact.id
      final contactId = c.id;
      final rawName = '${c.name.last} ${c.name.first}'.trim();
      final finalName = rawName.isNotEmpty ? rawName : '(No Name)';

      if (c.phones.isEmpty) continue;
      final rawPhone = c.phones.first.number.trim();
      if (rawPhone.isEmpty) continue;

      final normPhone = normalizePhone(rawPhone);

      // contactId + name + phoneNumber
      deviceList.add(
        PhoneBookModel(
          contactId: contactId,
          name: finalName,
          phoneNumber: normPhone,
          memo: null,
          type: null,
          updatedAt: null,
        ),
      );
    }

    final mergedList = <PhoneBookModel>[];
    final diffList = <PhoneBookModel>[];

    for (final deviceItem in deviceList) {
      final phoneKey = deviceItem.phoneNumber;
      final oldItem = oldMap[phoneKey];

      if (oldItem == null) {
        // 새 연락처
        final newItem = deviceItem.copyWith(
          updatedAt: DateTime.now().toIso8601String(),
        );
        mergedList.add(newItem);
        diffList.add(newItem);
      } else {
        // 기존 연락처 (memo, type 유지)
        // 만약 contactId가 빈 문자열이었다면 여기서 갱신
        final newContactId =
            oldItem.contactId.isEmpty
                ? deviceItem.contactId
                : oldItem.contactId;

        final changedName = deviceItem.name != oldItem.name;
        if (changedName) {
          final updated = oldItem.copyWith(
            contactId: newContactId,
            name: deviceItem.name,
            updatedAt: DateTime.now().toIso8601String(),
          );
          mergedList.add(updated);
          diffList.add(updated);
        } else {
          // contactId만 업데이트가 필요할 수도 있음
          final changedId = newContactId != oldItem.contactId;
          if (changedId) {
            final updated = oldItem.copyWith(
              contactId: newContactId,
              updatedAt: DateTime.now().toIso8601String(),
            );
            mergedList.add(updated);
            diffList.add(updated);
          } else {
            mergedList.add(oldItem);
          }
        }
      }
      oldMap.remove(phoneKey);
    }

    // 로컬에만 남은 번호 => 삭제
    // => mergedList에는 추가 X

    mergedList.sort((a, b) => a.name.compareTo(b.name));

    if (diffList.isNotEmpty) {
      log(
        '[ContactsController] Found ${diffList.length} changed => uploading...',
      );
      await _uploadDiff(diffList);
    }

    await saveLocalPhoneBook(mergedList);
    appEventBus.fire(ContactsUpdatedEvent());
  }

  /// 2) 메모/타입만 업데이트 (전화번호는 변경 불가)
  Future<void> updateMemoAndType({
    required String phoneNumber,
    required String memo,
    required int type,
    String? updatedName,
  }) async {
    final list = _getLocalPhoneBook();
    final idx = list.indexWhere((e) => e.phoneNumber == phoneNumber);
    if (idx < 0) {
      return;
    }

    final old = list[idx];
    final newItem = old.copyWith(
      memo: memo,
      type: type,
      name: updatedName ?? old.name,
      updatedAt: DateTime.now().toIso8601String(),
    );
    list[idx] = newItem;

    await saveLocalPhoneBook(list);
    // 이후 refreshContactsWithDiff() 호출 시 서버 업로드
  }

  /// 로컬 목록 읽기
  List<PhoneBookModel> _getLocalPhoneBook() {
    final raw = box.read<String>(storageKey);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.map((e) => PhoneBookModel.fromJson(e)).toList();
    } catch (e) {
      log('[ContactsController] parse error: $e');
      return [];
    }
  }

  /// 로컬 목록 쓰기
  Future<void> saveLocalPhoneBook(List<PhoneBookModel> list) async {
    final jsonList = list.map((m) => m.toJson()).toList();
    final raw = jsonEncode(jsonList);
    await box.write(storageKey, raw);
  }

  /// 외부에서 호출: 로컬 저장된 연락처 전체 얻기
  List<PhoneBookModel> getSavedContacts() {
    return _getLocalPhoneBook();
  }

  /// 서버 업로드
  Future<void> _uploadDiff(List<PhoneBookModel> diffList) async {
    final records =
        diffList.map((m) {
          return {
            'phoneNumber': m.phoneNumber,
            'name': m.name,
            'memo': m.memo ?? '',
            'type': m.type ?? 0,
            'createdAt': m.updatedAt ?? DateTime.now().toIso8601String(),
          };
        }).toList();

    try {
      log('[ContactsController] upsertPhoneRecords count=${records.length}');
      await PhoneRecordsApi.upsertPhoneRecords(records);
    } catch (e) {
      log('[ContactsController] upsertPhoneRecords error: $e');
    }
  }
}
