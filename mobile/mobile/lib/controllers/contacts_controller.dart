// lib/controllers/contacts_controller.dart
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
  static const storageKey = 'myPhoneBook';
  // "fastContacts" 대신 "myPhoneBook" 등으로 명칭 변경

  /// 디바이스 주소록 + (기존 memo/type) 병합 -> 최종본
  /// 그 후 diff 비교하여 변경된 것만 서버 업로드
  Future<void> refreshContactsWithDiff() async {
    // 1) 기존 로컬 목록(= 과거버전)
    final oldList = _getLocalPhoneBook();

    // 2) 디바이스 주소록 (fast_contacts)
    final deviceContacts = await FastContacts.getAllContacts();
    final deviceList = <PhoneBookModel>[];
    for (final c in deviceContacts) {
      if (c.phones.isEmpty) continue;
      final rawPhone = c.phones.first.number.trim();
      if (rawPhone.isEmpty) continue;

      final normPhone = normalizePhone(rawPhone);
      deviceList.add(
        PhoneBookModel(
          id: c.id ?? '',
          name: c.displayName ?? '',
          phoneNumber: normPhone,
          memo: null,
          type: null,
          updatedAt: null,
        ),
      );
    }

    // 이름 기준 정렬
    deviceList.sort((a, b) => a.name.compareTo(b.name));

    // 3) 병합(Merge): 디바이스 + oldList 의 memo, type 유지
    final mergedList = <PhoneBookModel>[];
    final oldMap = <String, PhoneBookModel>{};
    for (final o in oldList) {
      oldMap[o.phoneNumber] = o;
    }

    for (final d in deviceList) {
      final old = oldMap[d.phoneNumber];
      if (old == null) {
        // 새 연락처
        mergedList.add(d.copyWith(updatedAt: DateTime.now().toIso8601String()));
      } else {
        // 기존 memo/type 유지
        mergedList.add(
          old.copyWith(
            id: d.id, // 디바이스 id 갱신
            name: d.name,
            // phoneNumber 동일
          ),
        );
      }
    }

    // (선택) oldList 중 디바이스에 없는 번호도 보존
    for (final o in oldList) {
      final exists = mergedList.any((x) => x.phoneNumber == o.phoneNumber);
      if (!exists) {
        mergedList.add(o);
      }
    }

    // 4) 새 목록을 "로컬 임시"로 저장하지 않고, 우선 Diff 계산
    final diffList = _computeDiff(oldList, mergedList);

    // 5) diffList 가 있으면 -> 서버 업로드
    if (diffList.isNotEmpty) {
      log(
        '[ContactsController] Found ${diffList.length} changed items => uploading...',
      );
      await _uploadDiff(diffList);
    } else {
      log('[ContactsController] No changed items => skip upload.');
    }

    // 6) 최종 mergedList 를 로컬에 저장 (업로드 성공 후)
    await _saveLocalPhoneBook(mergedList);

    // 7) 이벤트
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

  /// 외부 용도: 화면에서 "현재 저장된 연락처"를 읽어온다
  List<PhoneBookModel> getSavedContacts() {
    return _getLocalPhoneBook();
  }

  /// Diff 계산 (간단 예: updatedAt or Hash or 전체필드 비교)
  List<PhoneBookModel> _computeDiff(
    List<PhoneBookModel> oldList,
    List<PhoneBookModel> newList,
  ) {
    // 여기서는 "updatedAt"이 null이 아니면 바뀌었다고 치거나,
    // 또는 phoneNumber를 key로, memo/type 변화 감지 등 커스텀 로직 가능

    final oldMap = <String, PhoneBookModel>{};
    for (final o in oldList) {
      oldMap[o.phoneNumber] = o;
    }

    final diff = <PhoneBookModel>[];
    for (final n in newList) {
      final o = oldMap[n.phoneNumber];
      if (o == null) {
        // 완전 신규
        diff.add(n);
      } else {
        // memo/type이 달라졌거나 updatedAt이 변경된 경우 => diff
        if (n.memo != o.memo ||
            n.type != o.type ||
            n.updatedAt != o.updatedAt) {
          diff.add(n);
        }
      }
    }

    return diff;
  }

  /// 서버 업로드 (diffList 만)
  Future<void> _uploadDiff(List<PhoneBookModel> diffList) async {
    final records =
        diffList.map((m) {
          // 서버 전송용 Map
          return {
            'phoneNumber': m.phoneNumber,
            'name': m.name,
            'memo': m.memo ?? '',
            'type': m.type ?? 0,
            'createdAt': m.updatedAt ?? DateTime.now().toIso8601String(),
            // userName, userType 은 서버에서 (isAdmin ? record값 : user.name/ type) 논리에 따라 처리
          };
        }).toList();

    try {
      log('test try upload');
      await PhoneRecordsApi.upsertPhoneRecords(records);
    } catch (e) {
      log('[ContactsController] upsertPhoneRecords error: $e');
      // 업로드 실패 시 -> 로컬에선 어떻게 처리할지(rollback?)는 정책에 따라
    }
  }
}
