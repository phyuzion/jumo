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

class ContactsController with ChangeNotifier {
  // GetStorage 관련 멤버 변수 완전 제거
  // final _box = GetStorage();
  // static const storageKey = 'phonebook';
  // static List<PhoneBookModel> _savedContacts = [];
  // static Map<String, PhoneBookModel> _contactIndex = {};
  // static DateTime? _lastSyncTime;
  // static const _cacheValidityDuration = Duration(minutes: 5);

  // 메모리 캐시 (유지)
  List<PhoneBookModel> _contacts = [];
  Map<String, PhoneBookModel> _contactCache =
      {}; // <<< 기존 캐시 유지 또는 _contacts 사용
  bool _isLoading = false;
  DateTime? _lastLoadTime; // <<< 마지막 로드 시간 추가 (선택적 최적화)

  // 이전 동기화 상태 저장 키 정의 (유지)
  static const String _lastSyncStateKey = 'contacts_state';

  ContactsController() {
    // 앱 시작 시 또는 필요 시 백그라운드 동기화 시작
    // TODO: 앱 라이프사이클 이벤트 또는 다른 트리거와 연동 필요
    triggerBackgroundSync();
  }

  /// 현재 로컬 연락처 목록 가져오기 (수정됨)
  Future<List<PhoneBookModel>> getLocalContacts({
    bool forceRefresh = false, // <<< 강제 새로고침 옵션 추가
  }) async {
    // <<< 캐시 및 로딩 상태 확인 >>>
    final now = DateTime.now();
    if (!forceRefresh &&
        _lastLoadTime != null &&
        now.difference(_lastLoadTime!) <
            const Duration(minutes: 1) && // 예: 1분 캐시
        _contacts.isNotEmpty) {
      log('[ContactsController] Using cached contacts.');
      return _contacts;
    }
    if (_isLoading) {
      log('[ContactsController] Already loading contacts...');
      // 로딩 중일 때 현재 캐시 반환 또는 Future 기다리기? (우선 현재 캐시 반환)
      return _contacts;
    }

    log(
      '[ContactsController] Fetching contacts from device... ForceRefresh: $forceRefresh',
    );
    // <<< 상태 변경을 마이크로태스크로 지연 >>>
    Future.microtask(() {
      // if (mounted) { // <<< 제거
      // Check if still relevant before updating state
      if (!_isLoading) {
        // 혹시 모를 중복 방지
        _isLoading = true;
        notifyListeners(); // 로딩 시작 알림
      }
      // }
    });

    try {
      final hasPermission = await FlutterContacts.requestPermission(
        readonly: true,
      );
      if (!hasPermission) {
        log('[ContactsController] Contact permission denied.');
        throw Exception('연락처 접근 권한이 거부되었습니다.');
      }

      final contactsRaw = await FlutterContacts.getContacts(
        withProperties: true,
        withPhoto: false,
        withThumbnail: false,
      );

      // 파싱은 compute 사용 유지
      final phoneBookModels = await compute(_parseContacts, contactsRaw);

      // <<< 로드 완료 후 상태 업데이트 및 알림 >>>
      // 이 부분은 비동기 작업 완료 후이므로 microtask 필요 없음
      _contacts = phoneBookModels;
      _contactCache = {for (var c in _contacts) c.phoneNumber: c};
      _lastLoadTime = now;
      _isLoading = false;
      notifyListeners();

      return _contacts;
    } catch (e) {
      log('[ContactsController] Error fetching device contacts: $e');
      // <<< 오류 시에도 microtask 또는 다음 프레임 콜백 사용 고려 >>>
      Future.microtask(() {
        // <<< microtask 추가
        // if (mounted) { // <<< 제거
        _isLoading = false;
        notifyListeners();
        // }
      });
      throw e;
    }
  }

  /// 백그라운드 동기화 트리거 (변경 없음)
  void triggerBackgroundSync() {
    log('[ContactsController] Requesting background contact sync...');
    // TODO: 백그라운드 서비스에 동기화 시작 이벤트 보내기
    // 예: FlutterBackgroundService().invoke('startContactSyncNow');
    // 또는 주기적 실행에 맡김
  }

  // 캐시 초기화 메소드 (변경 없음 - 내부 변수 초기화)
  void invalidateCache() {
    _contacts = [];
    _contactCache = {};
    _lastLoadTime = null;
    log('[ContactsController] Contacts cache invalidated.');
    notifyListeners(); // 캐시 무효화 알림
  }

  // <<< Getters 추가 >>>
  List<PhoneBookModel> get contacts => _contacts;
  Map<String, PhoneBookModel> get contactCache => _contactCache;
  bool get isLoading => _isLoading;

  // <<< 이름 조회 함수 추가 (Provider 대신 Controller에 위치) >>>
  Future<String> getContactName(String phoneNumber) async {
    final normalizedNumber = normalizePhone(phoneNumber);
    // 캐시 먼저 확인
    if (_contactCache.containsKey(normalizedNumber)) {
      return _contactCache[normalizedNumber]!.name;
    }
    // 캐시 없으면 전체 로드 (하지만 보통 미리 로드되어 있을 것)
    final contacts = await getLocalContacts();
    try {
      final contact = contacts.firstWhere(
        (c) => c.phoneNumber == normalizedNumber,
        orElse: () => PhoneBookModel(contactId: '', name: '', phoneNumber: ''),
      );
      return contact.name.isNotEmpty ? contact.name : '';
    } catch (e) {
      log(
        '[ContactsController] Error finding contact name for $normalizedNumber: $e',
      );
      return '';
    }
  }
}
