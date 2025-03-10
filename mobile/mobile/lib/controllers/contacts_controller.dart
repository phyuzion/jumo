import 'dart:convert';
import 'dart:developer';

import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:get_storage/get_storage.dart';
import 'package:mobile/graphql/phone_records_api.dart';
import 'package:mobile/models/phone_book_model.dart';
import 'package:mobile/utils/app_event_bus.dart';
import 'package:mobile/utils/constants.dart';

/// 디바이스 연락처 + (로컬메모/타입) + 서버 업서트 (sync) 담당
class ContactsController {
  final _box = GetStorage();
  static const storageKey = 'phonebook';

  /// 메인: 서버&디바이스&로컬 동기화
  /// 1) 서버에서 getMyRecords
  /// 2) 디바이스 주소록 불러오기
  /// 3) 3자 병합
  /// 4) diff -> 서버 업서트
  /// 5) 로컬 DB 저장
  Future<void> syncContactsAll() async {
    log('[ContactsController] syncContactsAll start...');
    // A. 서버 목록
    final serverList = await PhoneRecordsApi.getMyRecords();
    // B. 디바이스 목록
    final deviceContacts = await FlutterContacts.getContacts(
      withProperties: true,
      withAccounts: true,
    );
    final deviceList = <PhoneBookModel>[];
    for (final c in deviceContacts) {
      if (c.phones.isEmpty) continue;
      final rawPhone = c.phones.first.number.trim();
      if (rawPhone.isEmpty) continue;

      final normPhone = normalizePhone(rawPhone);
      // 이름: last+first
      final rawName = '${c.name.last} ${c.name.first}'.trim();
      final finalName = rawName.isNotEmpty ? rawName : '(No Name)';

      deviceList.add(
        PhoneBookModel(
          contactId: c.id,
          name: finalName,
          phoneNumber: normPhone,
          memo: null,
          type: null,
          updatedAt: null,
        ),
      );
    }

    // C. 기존 로컬
    final oldList = _loadLocalPhoneBook();

    // D. 병합
    final merged = _mergeAll(
      serverList: serverList,
      deviceList: deviceList,
      oldList: oldList,
    );

    // E. diff => 서버 업서트
    final diffList = _computeDiffForServer(merged, serverList);
    if (diffList.isNotEmpty) {
      log('[ContactsController] found ${diffList.length} diff => upsert');
      await _uploadDiff(diffList);
    } else {
      log('[ContactsController] no diff => skip upsert');
    }

    // F. 로컬 저장
    await _saveLocalPhoneBook(merged);

    // G. 이벤트
    appEventBus.fire(ContactsUpdatedEvent());
    log('[ContactsController] syncContactsAll done');
  }

  /// 외부에서 "현재 로컬 저장된 연락처" 조회
  List<PhoneBookModel> getSavedContacts() {
    return _loadLocalPhoneBook();
  }

  /// (새 메모/타입/이름)이 생겼을 때 로컬에 추가 or 갱신
  /// => 이후 syncContactsAll() 하면 서버도 업서트
  Future<void> addOrUpdateLocalRecord(PhoneBookModel newItem) async {
    final list = _loadLocalPhoneBook();
    final idx = list.indexWhere((e) => e.phoneNumber == newItem.phoneNumber);
    if (idx >= 0) {
      list[idx] = newItem;
    } else {
      list.add(newItem);
    }
    await _saveLocalPhoneBook(list);
  }

  /// 내부: 병합 (server vs device vs oldLocal)
  List<PhoneBookModel> _mergeAll({
    required List<Map<String, dynamic>> serverList,
    required List<PhoneBookModel> deviceList,
    required List<PhoneBookModel> oldList,
  }) {
    // server map
    final serverMap = <String, Map<String, dynamic>>{};
    for (var s in serverList) {
      final phone = normalizePhone(s['phoneNumber']);
      serverMap[phone] = s;
    }

    // old map
    final oldMap = <String, PhoneBookModel>{
      for (var o in oldList) o.phoneNumber: o,
    };

    // device map
    final deviceMap = <String, PhoneBookModel>{
      for (var d in deviceList) d.phoneNumber: d,
    };

    final mergedSet = <PhoneBookModel>{};

    // A. 서버 기준
    for (var entry in serverMap.entries) {
      final phone = entry.key;
      final s = entry.value;
      final deviceItem = deviceMap[phone];
      final oldItem = oldMap[phone];

      // 메모/타입 => 서버 or oldItem
      final sMemo = s['memo'] as String? ?? '';
      final sType = s['type'] as int? ?? 0;

      final finalMemo = sMemo.isNotEmpty ? sMemo : (oldItem?.memo ?? '');
      final finalType = sType != 0 ? sType : (oldItem?.type ?? 0);

      // 이름 => 디바이스 우선 → deviceItem?.name ?? s.name
      final sName = s['name'] as String? ?? '';
      final finalName =
          (deviceItem != null && deviceItem.name.isNotEmpty)
              ? deviceItem.name
              : sName;

      // contactId => oldItem or deviceItem
      String finalContactId = '';
      if (oldItem != null && oldItem.contactId.isNotEmpty) {
        finalContactId = oldItem.contactId;
      } else if (deviceItem != null && deviceItem.contactId.isNotEmpty) {
        finalContactId = deviceItem.contactId;
      }

      mergedSet.add(
        PhoneBookModel(
          contactId: finalContactId,
          name: finalName,
          phoneNumber: phone,
          memo: finalMemo.isNotEmpty ? finalMemo : null,
          type: finalType != 0 ? finalType : null,
          updatedAt: oldItem?.updatedAt,
        ),
      );
    }

    // B. 디바이스 중 서버에 없는 번호
    for (var d in deviceList) {
      if (!serverMap.containsKey(d.phoneNumber)) {
        final oldItem = oldMap[d.phoneNumber];
        final finalMemo = oldItem?.memo ?? '';
        final finalType = oldItem?.type ?? 0;
        mergedSet.add(
          d.copyWith(
            memo: finalMemo.isNotEmpty ? finalMemo : null,
            type: finalType != 0 ? finalType : null,
            updatedAt: oldItem?.updatedAt,
          ),
        );
      }
    }

    // C. oldList 중 server/device 모두 없는 => 삭제 or ignore
    //   여기서는 ignore

    final mergedList = mergedSet.toList();
    mergedList.sort((a, b) => a.name.compareTo(b.name));
    return mergedList;
  }

  /// 서버와의 diff
  List<PhoneBookModel> _computeDiffForServer(
    List<PhoneBookModel> mergedList,
    List<Map<String, dynamic>> serverList,
  ) {
    final serverMap = <String, Map<String, dynamic>>{};
    for (var s in serverList) {
      final phone = normalizePhone(s['phoneNumber']);
      serverMap[phone] = s;
    }

    final diff = <PhoneBookModel>[];
    for (var m in mergedList) {
      final s = serverMap[m.phoneNumber];
      if (s == null) {
        // 서버에 없는 => diff
        diff.add(
          m.copyWith(
            updatedAt: m.updatedAt ?? DateTime.now().toIso8601String(),
          ),
        );
      } else {
        final sName = s['name'] as String? ?? '';
        final sMemo = s['memo'] as String? ?? '';
        final sType = s['type'] as int? ?? 0;

        final changedName = m.name != sName;
        final changedMemo = (m.memo ?? '') != sMemo;
        final changedType = (m.type ?? 0) != sType;

        if (changedName || changedMemo || changedType) {
          diff.add(
            m.copyWith(
              updatedAt: m.updatedAt ?? DateTime.now().toIso8601String(),
            ),
          );
        }
      }
    }
    return diff;
  }

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

    await PhoneRecordsApi.upsertPhoneRecords(records);
  }

  // ------ 로컬 DB

  // 내부: 로컬 목록 저장
  Future<void> _saveLocalPhoneBook(List<PhoneBookModel> list) async {
    final raw = jsonEncode(list.map((e) => e.toJson()).toList());
    await _box.write(storageKey, raw);
  }

  // 내부: 로컬 목록 읽기
  List<PhoneBookModel> _loadLocalPhoneBook() {
    final raw = _box.read<String>(storageKey);
    if (raw == null) return [];
    try {
      final decoded = jsonDecode(raw) as List;
      return decoded.map((e) => PhoneBookModel.fromJson(e)).toList();
    } catch (e) {
      log('[ContactsController] parse error: $e');
      return [];
    }
  }
}
