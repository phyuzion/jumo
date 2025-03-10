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

  /// 1) 디바이스 주소록 읽기 (flutter_contacts)
  /// 2) 로컬 저장소와 비교
  ///    - 디바이스엔 있는데 로컬에 없으면 => 신규
  ///    - 디바이스엔 없는데 로컬에만 있으면 => 삭제
  ///    - 둘 다 있으면 => name은 디바이스 것 우선, memo/type은 로컬 것 유지
  ///    - 변경/신규된 항목만 diff로 서버 업로드
  /// 3) 최종 mergedList 로컬 저장
  /// 4) 이벤트
  Future<void> refreshContactsWithDiff() async {
    // B. 기존 로컬 목록
    final oldList = _getLocalPhoneBook();
    final oldMap = <String, PhoneBookModel>{
      for (var o in oldList) o.phoneNumber: o,
    };

    // C. flutter_contacts 로 주소록 읽기
    //    withProperties: true => 이름/전화번호 등 세부 속성 포함
    final deviceContacts = await FlutterContacts.getContacts(
      withProperties: true,
    );
    final deviceList = <PhoneBookModel>[];

    for (final c in deviceContacts) {
      // 이름: lastName + firstName
      final rawName = '${c.name.last} ${c.name.first}'.trim();
      // 혹시 둘 다 없는 경우가 있을 수 있으니 대비
      final finalName = rawName.isNotEmpty ? rawName : '(No Name)';

      // 전화번호가 하나도 없으면 skip
      if (c.phones.isEmpty) continue;
      final rawPhone = c.phones.first.number.trim();
      if (rawPhone.isEmpty) continue;

      // normalize
      final normPhone = normalizePhone(rawPhone);

      deviceList.add(
        PhoneBookModel(
          name: finalName,
          phoneNumber: normPhone,
          memo: null,
          type: null,
          updatedAt: null,
        ),
      );
    }

    // D. 병합 + diff 추출
    final mergedList = <PhoneBookModel>[];
    final diffList = <PhoneBookModel>[];

    for (final deviceItem in deviceList) {
      final phoneKey = deviceItem.phoneNumber;
      final oldItem = oldMap[phoneKey];

      if (oldItem == null) {
        // 신규
        final newItem = deviceItem.copyWith(
          updatedAt: DateTime.now().toIso8601String(),
        );
        mergedList.add(newItem);
        diffList.add(newItem);
      } else {
        // 기존 -> memo/type은 로컬 유지, 이름은 디바이스 우선
        final finalName = deviceItem.name;
        final finalMemo = oldItem.memo;
        final finalType = oldItem.type;

        // 변경 여부
        final changedName = finalName != oldItem.name;
        final changedMemo = false;
        final changedType = false;

        if (changedName) {
          final updated = oldItem.copyWith(
            name: finalName,
            updatedAt: DateTime.now().toIso8601String(),
          );
          mergedList.add(updated);
          diffList.add(updated);
        } else {
          mergedList.add(oldItem);
        }
      }
      // 처리된 번호는 oldMap에서 제거
      oldMap.remove(phoneKey);
    }

    // 2) 디바이스에 없고 oldMap에만 남은 번호 => 삭제
    //    => mergedList에 넣지 않음
    //    => 서버에도 삭제할지는 정책에 따라 다름 (여기서는 업로드 X)

    // (oldMap에 남은 것 => 제거된 번호)
    // -> 만약 서버에 삭제 API를 보내야 한다면 따로 diffDeleteList 등을 처리

    // E. 정렬(선택사항)
    mergedList.sort((a, b) => a.name.compareTo(b.name));

    // F. 서버 업로드
    if (diffList.isNotEmpty) {
      log(
        '[ContactsController] Found ${diffList.length} changed/new items => uploading...',
      );
      await _uploadDiff(diffList);
    } else {
      log('[ContactsController] No changed/new items => skip upload.');
    }

    // G. 로컬 저장
    await _saveLocalPhoneBook(mergedList);

    // H. 이벤트
    appEventBus.fire(ContactsUpdatedEvent());
  }

  /// 로컬에서 읽기
  List<PhoneBookModel> _getLocalPhoneBook() {
    final raw = box.read<String>(storageKey);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.map((e) => PhoneBookModel.fromJson(e)).toList();
    } catch (e) {
      log('parse error: $e');
      return [];
    }
  }

  /// 로컬에 쓰기
  Future<void> _saveLocalPhoneBook(List<PhoneBookModel> list) async {
    final jsonList = list.map((m) => m.toJson()).toList();
    final raw = jsonEncode(jsonList);
    await box.write(storageKey, raw);
  }

  /// 외부에서 현재 로컬 저장된 연락처 얻기
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
      log('[ContactsController] upsertPhoneRecords: ${records.length} records');
      await PhoneRecordsApi.upsertPhoneRecords(records);
    } catch (e) {
      log('[ContactsController] upsertPhoneRecords error: $e');
      // 업로드 실패 시 -> 로컬에서 어떻게 할지는 정책에 따라
    }
  }
}
