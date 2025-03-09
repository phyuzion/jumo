import 'dart:developer';
import 'package:fast_contacts/fast_contacts.dart';
import 'package:get_storage/get_storage.dart';
import 'package:mobile/graphql/phone_records_api.dart'; // upsertPhoneRecords() 가정
import 'package:mobile/utils/app_event_bus.dart';
import 'package:mobile/utils/constants.dart';

class ContactsController {
  final box = GetStorage();
  static const storageKey = 'fastContacts';

  /// 주소록(디바이스) + 로컬(기존 memo/type) 머지하여 최종 목록을 만든 뒤 저장.
  /// - return: 최종 머지된 목록(또는 diff된 목록)
  Future<void> refreshContactsMerged() async {
    // 1) 기존 로컬 목록 (id, name, phones, memo, type, …)
    final oldList = getSavedContacts();

    // 2) 디바이스 주소록
    final deviceContacts = await FastContacts.getAllContacts();

    // 변환: [{id, name, phones}, …]
    final deviceList = <Map<String, dynamic>>[];
    for (final c in deviceContacts) {
      if (c.phones.isEmpty) continue;
      final phone = c.phones.first.number.trim();
      if (phone.isEmpty) continue;

      deviceList.add({
        'id': c.id ?? '',
        'name': c.displayName ?? '',
        'phones': normalizePhone(phone),
        // memo, type 은 아직 없음
      });
    }

    // 이름 오름차순 정렬
    deviceList.sort((a, b) {
      final aName = (a['name'] ?? '') as String;
      final bName = (b['name'] ?? '') as String;
      return aName.compareTo(bName);
    });

    // 3) Merge:
    //   - oldList 에 memo/type 있을 수 있음 => 유지
    //   - deviceList 에 새 연락처 있을 수 있음 => 추가
    final mergedList = <Map<String, dynamic>>[];

    // (3-1) oldList phone → Map
    final oldMap = <String, Map<String, dynamic>>{};
    for (final o in oldList) {
      final ph = (o['phones'] ?? '').toString().trim();
      if (ph.isNotEmpty) {
        oldMap[ph] = o;
      }
    }

    // (3-2) deviceList 순회 & merge
    for (final d in deviceList) {
      final phone = (d['phones'] ?? '').toString();
      final old = oldMap[phone];
      if (old == null) {
        // 완전 새 연락처
        mergedList.add(d);
      } else {
        // 기존 memo/type 등을 유지
        final merged = {
          'id': d['id'],
          'name': d['name'],
          'phones': phone,
          // 보존 필드
          'memo': old['memo'],
          'type': old['type'],
        };
        mergedList.add(merged);
      }
    }

    // (선택) oldList 중 deviceList에는 없는 연락처(= 앱에서만 등록했던 번호)도 유지?
    for (final o in oldList) {
      final phone = (o['phones'] ?? '').toString();
      final alreadyExists = mergedList.any((m) => (m['phones'] == phone));
      if (!alreadyExists) {
        // 연락처 앱에는 없지만, 앱/서버에서는 유지하고 싶다면
        mergedList.add(o);
      }
    }

    // 4) 로컬에 최종 mergedList 저장
    await box.write(storageKey, mergedList);

    // 5) 변경 이벤트
    appEventBus.fire(ContactsUpdatedEvent());

    log(
      '[ContactsController] refreshContactsMerged -> mergedList: ${mergedList.length}개',
    );
    syncContactsToServer();
  }

  /// 주소록(로컬) -> 서버
  Future<void> syncContactsToServer() async {
    // 1) 로컬 저장된(머지완료) 연락처
    final contacts = getSavedContacts();
    // 구조: [{id, name, phones, memo, type}, ...]

    // 2) 서버에 넘길 "PhoneRecordInput"
    final records = <Map<String, dynamic>>[];
    for (final c in contacts) {
      final phone = (c['phones'] ?? '').toString().trim();
      if (phone.isEmpty) continue;

      final record = <String, dynamic>{
        'phoneNumber': phone,
        'name': c['name'] ?? '',
        'memo': c['memo'] ?? '',
        'type': c['type'] ?? 0,
        // createdAt, userName/userType 등 필요한 필드
        'createdAt': DateTime.now().toIso8601String(),
      };
      records.add(record);
    }

    // 3) API 호출
    try {
      await PhoneRecordsApi.upsertPhoneRecords(records);
    } catch (e) {
      log('[ContactsController] 연락처 서버전송 에러: $e');
    }
  }

  /// 로컬에 저장된 연락처 읽기
  /// 구조: [{ id, name, phones, memo, type }, ...]
  List<Map<String, dynamic>> getSavedContacts() {
    final list = box.read<List>(storageKey) ?? [];
    return list.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  /// (추가) 특정 전화번호 항목의 memo/type 수정하기
  /// - 앱 내에서 사용자가 “메모 수정” 등의 기능 시
  Future<void> updateMemoType(String phone, String? memo, int? type) async {
    final all = getSavedContacts();
    bool changed = false;
    for (final item in all) {
      if ((item['phones'] ?? '') == phone) {
        if (memo != null) item['memo'] = memo;
        if (type != null) item['type'] = type;
        changed = true;
        break;
      }
    }
    if (changed) {
      await box.write(storageKey, all);
      appEventBus.fire(ContactsUpdatedEvent());
      log('[ContactsController] updateMemoType($phone) saved');
    }
  }
}
