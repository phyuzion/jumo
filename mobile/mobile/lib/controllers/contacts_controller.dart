import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:hive_ce/hive.dart';
import 'package:mobile/graphql/phone_records_api.dart';
import 'package:mobile/models/phone_book_model.dart';
import 'package:mobile/utils/constants.dart';

// compute 함수를 사용하기 위해 top-level 함수로 분리
List<PhoneBookModel> _parseContacts(List<Contact> contacts) {
  final List<PhoneBookModel> result = [];
  for (final c in contacts) {
    if (c.phones.isEmpty) continue;
    // 가장 첫번째 전화번호만 사용
    final rawPhone = c.phones.first.number.trim();
    if (rawPhone.isEmpty) continue;

    final normPhone = normalizePhone(rawPhone);
    final rawName = c.displayName.trim(); // displayName 사용
    final finalName = rawName.isNotEmpty ? rawName : '(No Name)';

    result.add(
      PhoneBookModel(
        contactId: c.id, // 디바이스 연락처 ID
        name: finalName,
        phoneNumber: normPhone,
      ),
    );
  }
  return result;
}

// compute 함수를 사용하기 위해 top-level 함수로 분리
Map<String, Map<String, String>> _parseContactsToMap(List<Contact> contacts) {
  final Map<String, Map<String, String>> resultMap = {};
  for (var c in contacts) {
    if (c.phones.isNotEmpty) {
      final phone = normalizePhone(c.phones.first.number.trim());
      final name =
          c.displayName.trim().isNotEmpty ? c.displayName.trim() : '(No Name)';
      resultMap[c.id] = {'name': name, 'phoneNumber': phone};
    }
  }
  return resultMap;
}

/// 백그라운드 연락처 동기화 로직 (top-level 함수)
Future<void> performContactBackgroundSync() async {
  log('[BackgroundSync] Starting contact sync...');

  // ***** Box 열림 확인 추가 *****
  const boxName = 'last_sync_state';
  if (!Hive.isBoxOpen(boxName)) {
    log('[BackgroundSync] Box \'$boxName\' is not open. Aborting sync.');
    return; // Box가 안 열렸으면 작업 중단
  }
  final Box stateBox = Hive.box(boxName);

  try {
    // 1. 현재 로컬 연락처 가져오기 (권한 확인 포함)
    List<Contact> currentContactsRaw;
    try {
      final hasPermission = await FlutterContacts.requestPermission(
        readonly: true,
      );
      if (!hasPermission) {
        log('[BackgroundSync] Permission denied.');
        return;
      }
      currentContactsRaw = await FlutterContacts.getContacts(
        withProperties: true,
        withPhoto: false,
        withThumbnail: false,
      );
    } catch (e) {
      log('[BackgroundSync] Error getting contacts: $e');
      return;
    }

    // 백그라운드 파싱
    final currentContactsMap = await compute(
      _parseContactsToMap,
      currentContactsRaw,
    );

    // 2. 이전 상태 로드 (Hive 사용)
    final previousStateRaw =
        stateBox.get(ContactsController._lastSyncStateKey) as String?;
    final previousContactsMap =
        previousStateRaw != null
            ? Map<String, Map<String, String>>.from(
              jsonDecode(previousStateRaw),
            )
            : <String, Map<String, String>>{};

    // 3. 변경 사항 계산 (추가/수정)
    final List<Map<String, dynamic>> recordsToUpsert = [];
    final Set<String> currentIds = currentContactsMap.keys.toSet();
    for (var id in currentIds) {
      final currentData = currentContactsMap[id]!;
      final previousData = previousContactsMap[id];
      bool changed = false;
      if (previousData == null ||
          currentData['name'] != previousData['name'] ||
          currentData['phoneNumber'] != previousData['phoneNumber']) {
        changed = true;
      }
      if (changed) {
        recordsToUpsert.add({
          'phoneNumber': currentData['phoneNumber']!,
          'name': currentData['name']!,
          'createdAt': DateTime.now().toUtc().toIso8601String(),
        });
      }
    }

    // 4. 삭제 로직 없음

    // 5. 변경 사항 서버에 업로드 (Hive 사용)
    if (recordsToUpsert.isNotEmpty) {
      log(
        '[BackgroundSync] Found ${recordsToUpsert.length} changes to upload.',
      );
      try {
        await PhoneRecordsApi.upsertPhoneRecords(recordsToUpsert);
        log('[BackgroundSync] Successfully attempted upload.');
        // 업로드 성공/실패 여부와 관계없이 현재 상태 Hive에 저장
        await stateBox.put(
          ContactsController._lastSyncStateKey,
          jsonEncode(currentContactsMap),
        );
        log('[BackgroundSync] Saved current state after attempt.');
      } catch (e) {
        log('[BackgroundSync] Failed to upload changes: $e');
        // 오류 로그만 남기고 재시도 안함
      }
    } else {
      log('[BackgroundSync] No changes detected.');
      // 변경 없어도 현재 상태 Hive에 저장
      await stateBox.put(
        ContactsController._lastSyncStateKey,
        jsonEncode(currentContactsMap),
      );
      log('[BackgroundSync] Saved current state (no changes).');
    }
  } catch (e, st) {
    log('[BackgroundSync] Sync error: $e\n$st');
  } finally {
    log('[BackgroundSync] Sync finished.');
  }
}

class ContactsController {
  // GetStorage 관련 멤버 변수 완전 제거
  // final _box = GetStorage();
  // static const storageKey = 'phonebook';
  // static List<PhoneBookModel> _savedContacts = [];
  // static Map<String, PhoneBookModel> _contactIndex = {};
  // static DateTime? _lastSyncTime;
  // static const _cacheValidityDuration = Duration(minutes: 5);

  // 메모리 캐시 (유지)
  List<PhoneBookModel> _memoryCache = [];
  DateTime? _lastMemoryCacheTime;
  static const _memoryCacheDuration = Duration(minutes: 1);

  // 이전 동기화 상태 저장 키 정의 (유지)
  static const String _lastSyncStateKey = 'contacts_state';

  ContactsController() {
    // 앱 시작 시 또는 필요 시 백그라운드 동기화 시작
    // TODO: 앱 라이프사이클 이벤트 또는 다른 트리거와 연동 필요
    triggerBackgroundSync();
  }

  /// 현재 로컬 연락처 목록 가져오기 (캐시 활용)
  Future<List<PhoneBookModel>> getLocalContacts() async {
    // 메모리 캐시 확인
    if (_lastMemoryCacheTime != null &&
        DateTime.now().difference(_lastMemoryCacheTime!) <
            _memoryCacheDuration &&
        _memoryCache.isNotEmpty) {
      log('[ContactsController] Using memory cache for local contacts');
      return _memoryCache;
    }

    log('[ContactsController] Fetching contacts from device...');
    try {
      // 연락처 접근 권한 확인 (선택적)
      final hasPermission = await FlutterContacts.requestPermission(
        readonly: true,
      );
      if (!hasPermission) {
        log('[ContactsController] Contact permission denied.');
        // TODO: 사용자에게 권한 필요 안내 또는 설정 이동 버튼 제공
        return []; // 권한 없으면 빈 리스트 반환
      }

      final contacts = await FlutterContacts.getContacts(
        withProperties: true, // 이름 필요
        withPhoto: false,
        withThumbnail: false,
      );

      // 백그라운드 스레드에서 파싱 (연락처 많을 때 UI 블록 방지)
      final phoneBookModels = await compute(_parseContacts, contacts);

      // 메모리 캐시 업데이트
      _memoryCache = phoneBookModels;
      _lastMemoryCacheTime = DateTime.now();

      return phoneBookModels;
    } catch (e) {
      log('[ContactsController] Error fetching device contacts: $e');
      // 권한 오류 외 다른 오류 처리
      return []; // 오류 시 빈 리스트 반환
    }
  }

  /// 백그라운드 동기화 트리거 (이제 백그라운드 서비스에 요청)
  void triggerBackgroundSync() {
    log('[ContactsController] Requesting background contact sync...');
    // TODO: 백그라운드 서비스에 동기화 시작 이벤트 보내기
    // 예: FlutterBackgroundService().invoke('startContactSyncNow');
    // 또는 주기적 실행에 맡김
  }
}
