import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:hive_ce/hive.dart';
import 'package:mobile/graphql/phone_records_api.dart';
import 'package:mobile/models/phone_book_model.dart';
import 'package:mobile/utils/constants.dart';
import 'package:crypto/crypto.dart';

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

// 해시 계산 헬퍼 함수
String _calculateContactHash(Contact contact) {
  // 해시 계산에 사용할 데이터 조합 (ID, 이름, 첫번째 전화번호)
  String combinedData = contact.id;
  if (contact.displayName.isNotEmpty) {
    combinedData += contact.displayName;
  }
  if (contact.phones.isNotEmpty) {
    final phone = contact.phones.first.number.trim();
    if (phone.isNotEmpty) {
      combinedData += normalizePhone(phone);
    }
  }
  // UTF-8 인코딩 후 SHA-256 해시 계산
  var bytes = utf8.encode(combinedData);
  var digest = sha256.convert(bytes);
  return digest.toString();
}

/// 백그라운드 연락처 동기화 로직 (top-level 함수)
Future<void> performContactBackgroundSync() async {
  final stopwatch = Stopwatch()..start(); // 전체 시간 측정
  log('[BackgroundSync] Starting contact sync (hash-based delta)...');
  const boxName = 'last_sync_state';
  if (!Hive.isBoxOpen(boxName)) {
    log('[BackgroundSync] Box \'$boxName\' is not open. Aborting sync.');
    return;
  }
  final Box stateBox = Hive.box(boxName);

  try {
    // 1. 현재 로컬 연락처 로드 및 현재 해시 맵 생성
    List<Contact> currentContactsRaw;
    final stepWatch = Stopwatch()..start(); // 단계별 측정
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
      log(
        '[BackgroundSync] Reading ${currentContactsRaw.length} contacts took: ${stepWatch.elapsedMilliseconds}ms',
      );
      stepWatch.reset();
    } catch (e) {
      log('[BackgroundSync] Error getting contacts: $e');
      return;
    }

    stepWatch.start();
    final Map<String, String> currentHashes = {};
    final Map<String, Contact> currentContactsById = {};
    for (final contact in currentContactsRaw) {
      final hash = _calculateContactHash(contact);
      currentHashes[contact.id] = hash;
      currentContactsById[contact.id] = contact;
    }
    log(
      '[BackgroundSync] Calculating ${currentContactsRaw.length} hashes took: ${stepWatch.elapsedMilliseconds}ms',
    );
    stepWatch.reset();

    // 2. 이전 상태 (해시 맵) 로드 (타입 확인 및 처리 강화)
    stepWatch.start();
    final previousStateData = stateBox.get(
      ContactsController._lastSyncStateKey,
    ); // dynamic으로 읽기
    Map<String, String> previousHashes = {};
    if (previousStateData != null) {
      try {
        if (previousStateData is String) {
          // 정상 케이스: 문자열이면 JSON 디코드 후 캐스팅
          final decodedDynamicMap =
              jsonDecode(previousStateData) as Map<String, dynamic>;
          previousHashes = decodedDynamicMap.map(
            (key, value) => MapEntry(key, value as String),
          );
          log('[BackgroundSync] Loaded previous state from JSON string.');
        } else if (previousStateData is Map) {
          // 비정상 케이스: 이전에 Map으로 잘못 저장된 경우
          log(
            '[BackgroundSync] Warning: Loaded previous state directly as Map. Converting manually and resaving as JSON string.',
          );
          previousHashes = <String, String>{}; // 새 맵 생성
          previousStateData.forEach((key, value) {
            // 타입 체크하며 안전하게 변환
            if (key is String && value is String) {
              previousHashes[key] = value;
            } else {
              log(
                '[BackgroundSync] Warning: Skipped invalid entry in stored map: key=${key.runtimeType}, value=${value.runtimeType}',
              );
            }
          });
          // 변환 후, 올바른 포맷(JSON 문자열)으로 다시 저장하여 문제 해결
          await stateBox.put(
            ContactsController._lastSyncStateKey,
            jsonEncode(previousHashes),
          );
        } else {
          // 예상치 못한 타입 저장된 경우
          log(
            '[BackgroundSync] Previous state has unexpected type: ${previousStateData.runtimeType}. Clearing state.',
          );
          await stateBox.delete(
            ContactsController._lastSyncStateKey,
          ); // 해당 키 데이터 삭제
        }
      } catch (e) {
        log('[BackgroundSync] Error processing previous contact hashes: $e');
        previousHashes = {}; // 오류 시 빈 맵 사용
        // 오류 발생 시 이전 상태 삭제 고려 (선택적)
        // await stateBox.delete(ContactsController._lastSyncStateKey);
      }
    }
    log(
      '[BackgroundSync] Loading previous state took: ${stepWatch.elapsedMilliseconds}ms',
    );
    stepWatch.reset();

    // 3. 변경 사항 계산
    stepWatch.start();
    final List<String> changedContactIds = [];
    for (final currentId in currentHashes.keys) {
      if (!previousHashes.containsKey(currentId) ||
          previousHashes[currentId] != currentHashes[currentId]) {
        changedContactIds.add(currentId);
      }
    }
    log(
      '[BackgroundSync] Calculating diff took: ${stepWatch.elapsedMilliseconds}ms, changes: ${changedContactIds.length}',
    );
    stepWatch.reset();

    // 4. 변경된 연락처 정보로 업로드 데이터 생성
    stepWatch.start();
    final List<Map<String, dynamic>> recordsToUpsert = [];
    for (final id in changedContactIds) {
      final contact = currentContactsById[id];
      if (contact != null && contact.phones.isNotEmpty) {
        final normPhone = normalizePhone(contact.phones.first.number.trim());
        final name =
            contact.displayName.trim().isNotEmpty
                ? contact.displayName.trim()
                : '(No Name)';
        if (normPhone.isNotEmpty) {
          recordsToUpsert.add({
            'phoneNumber': normPhone,
            'name': name,
            'createdAt': DateTime.now().toUtc().toIso8601String(),
          });
        }
      }
    }
    log(
      '[BackgroundSync] Preparing upload data took: ${stepWatch.elapsedMilliseconds}ms',
    );
    stepWatch.reset();

    // 5. 변경 사항 서버에 업로드
    if (recordsToUpsert.isNotEmpty) {
      log(
        '[BackgroundSync] Uploading ${recordsToUpsert.length} changed contacts...',
      );
      stepWatch.start();
      try {
        await PhoneRecordsApi.upsertPhoneRecords(recordsToUpsert);
        log(
          '[BackgroundSync] Upload successful, took: ${stepWatch.elapsedMilliseconds}ms',
        );
        // 업로드 성공 시 현재 해시 맵 저장
        await stateBox.put(
          ContactsController._lastSyncStateKey,
          jsonEncode(currentHashes),
        );
        log(
          '[BackgroundSync] Saved current contact hashes after successful upload.',
        );
      } catch (e) {
        log(
          '[BackgroundSync] Upload failed: $e, took: ${stepWatch.elapsedMilliseconds}ms',
        );
        // 업로드 실패 시 상태 저장 안 함 (다음 동기화 시 재시도)
      }
      stepWatch.stop();
    } else {
      log('[BackgroundSync] No contact changes detected.');
      // 변경 없어도 현재 해시 상태 저장
      await stateBox.put(
        ContactsController._lastSyncStateKey,
        jsonEncode(currentHashes),
      );
      log('[BackgroundSync] Saved current contact hashes (no changes).');
    }
  } catch (e, st) {
    log('[BackgroundSync] Sync error: $e\n$st');
  } finally {
    stopwatch.stop();
    log('[BackgroundSync] Total sync took: ${stopwatch.elapsedMilliseconds}ms');
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

  // 메모리 캐시 초기화 메소드 추가
  void invalidateCache() {
    _memoryCache = [];
    _lastMemoryCacheTime = null;
    log('[ContactsController] Memory cache invalidated.');
  }
}
