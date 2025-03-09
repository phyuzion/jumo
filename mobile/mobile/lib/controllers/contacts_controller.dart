import 'dart:convert';
import 'dart:developer';

import 'package:fast_contacts/fast_contacts.dart';
import 'package:get_storage/get_storage.dart';
import 'package:mobile/graphql/phone_records_api.dart';
import 'package:mobile/models/phone_book_model.dart';
import 'package:mobile/utils/app_event_bus.dart';
import 'package:mobile/utils/constants.dart';

class ContactsController {
  final box = GetStorage();
  static const storageKey = 'phonebook';

  /// 1) 디바이스 주소록 읽기
  /// 2) 로컬 저장소와 비교
  ///    - 디바이스엔 있는데 로컬에 없으면 => 신규
  ///    - 디바이스엔 없는데 로컬에만 있으면 => 삭제
  ///    - 둘 다 있으면 => name은 디바이스 것 우선, memo/type은 로컬 것 유지
  ///    - 변경/신규된 항목만 diff로 서버 업로드
  /// 3) 최종 mergedList 로컬 저장
  /// 4) 이벤트
  Future<void> refreshContactsWithDiff() async {
    // A. 기존 로컬 목록
    final oldList = _getLocalPhoneBook();
    final oldMap = <String, PhoneBookModel>{
      for (var o in oldList) o.phoneNumber: o,
    };

    // B. 디바이스 주소록
    final deviceContacts = await FastContacts.getAllContacts();
    final deviceList = <PhoneBookModel>[];
    for (final c in deviceContacts) {
      // skip empty
      if (c.phones.isEmpty) continue;
      final rawPhone = c.phones.first.number.trim();
      if (rawPhone.isEmpty) continue;

      final normPhone = normalizePhone(rawPhone);
      deviceList.add(
        PhoneBookModel(
          name: c.displayName ?? '',
          phoneNumber: normPhone,
          memo: null,
          type: null,
          updatedAt: null,
        ),
      );
    }

    // C. 최종 병합 리스트
    final mergedList = <PhoneBookModel>[];
    //    + 서버에 업로드할 diff 항목
    final diffList = <PhoneBookModel>[];

    // 1) 디바이스에 존재하는 모든 번호를 순회
    for (final deviceItem in deviceList) {
      final phoneKey = deviceItem.phoneNumber;
      final oldItem = oldMap[phoneKey];

      if (oldItem == null) {
        // (1) 로컬에 없던 신규 번호
        final newItem = deviceItem.copyWith(
          updatedAt: DateTime.now().toIso8601String(),
        );
        mergedList.add(newItem);
        diffList.add(newItem);
      } else {
        // (2) 기존에 있던 번호 => memo, type은 로컬 유지. name은 디바이스가 우선
        final finalName = deviceItem.name; // 디바이스 이름
        final finalMemo = oldItem.memo; // 로컬 memo
        final finalType = oldItem.type; // 로컬 type

        // 변경 여부 체크
        final changedName = finalName != oldItem.name;
        final changedMemo = false; // memo는 안 바뀌었으니 false
        final changedType = false; // type도 안 바뀌었으니 false

        if (changedName) {
          // 하나라도 바뀌었다면 updatedAt 갱신
          final updated = oldItem.copyWith(
            name: finalName,
            updatedAt: DateTime.now().toIso8601String(),
          );
          mergedList.add(updated);
          diffList.add(updated);
        } else {
          // 변경 없음
          mergedList.add(oldItem);
        }
      }
      // 처리된 번호는 oldMap에서 제거
      oldMap.remove(phoneKey);
    }

    // 2) 디바이스엔 없고 oldMap에만 남은 번호 => 삭제 처리
    //    즉, mergedList에 넣지 않는다.
    //    diffList로 보낼 필요도 없고(서버에 "삭제" 개념이 필요한지 여부는 정책에 따라),
    //    질문에서 "디바이스에서 삭제되면 로컬에서도 없애야 한다" 했으니 로컬에선 버린다.
    //    만약 서버에도 삭제 API를 호출하고 싶다면 따로 diffDeleteList를 만들어 처리하면 된다.
    //    여기서는 “추가/변경만 서버로 업로드”이므로 그냥 넘어간다.

    // 3) 이름 기준 정렬(선택)
    mergedList.sort((a, b) => a.name.compareTo(b.name));

    // D. diffList 서버 업로드
    if (diffList.isNotEmpty) {
      log(
        '[ContactsController] Found ${diffList.length} changed/new items => uploading... $diffList',
      );
      await _uploadDiff(diffList);
    } else {
      log('[ContactsController] No changed/new items => skip upload.');
    }

    // E. 최종 mergedList 로컬 저장
    await _saveLocalPhoneBook(mergedList);

    // F. 이벤트
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
