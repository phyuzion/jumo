import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:hive_ce/hive.dart';
import 'package:mobile/graphql/phone_records_api.dart';
import 'package:mobile/models/phone_book_model.dart';
import 'package:mobile/utils/constants.dart';
import 'package:crypto/crypto.dart';
import 'package:mobile/services/native_methods.dart';
import 'package:mobile/repositories/contact_repository.dart';

// 네이티브 연락처 파싱 함수
List<PhoneBookModel> _parseNativeContacts(List<Map<String, dynamic>> contacts) {
  final List<PhoneBookModel> result = [];
  for (final c in contacts) {
    final rawPhone = (c['phoneNumber'] ?? '').toString().trim();
    if (rawPhone.isEmpty) continue;
    final normPhone = normalizePhone(rawPhone);
    final rawName = (c['displayName'] ?? '').toString().trim();
    final finalName = rawName.isNotEmpty ? rawName : '(No Name)';
    result.add(
      PhoneBookModel(
        contactId: c['id']?.toString() ?? '',
        rawContactId: c['rawId']?.toString(),
        name: finalName,
        phoneNumber: normPhone,
        createdAt:
            c['lastUpdated'] != null
                ? DateTime.fromMillisecondsSinceEpoch(
                  c['lastUpdated'],
                  isUtc: true,
                )
                : null,
      ),
    );
  }
  return result;
}

// 네이티브 연락처 해시 계산
String _calculateNativeContactHash(Map<String, dynamic> contact) {
  String combinedData = contact['id']?.toString() ?? '';
  if ((contact['displayName'] ?? '').toString().isNotEmpty) {
    combinedData += contact['displayName'];
  }
  if ((contact['phoneNumber'] ?? '').toString().isNotEmpty) {
    combinedData += normalizePhone(contact['phoneNumber']);
  }
  var bytes = utf8.encode(combinedData);
  var digest = sha256.convert(bytes);
  return digest.toString();
}

/// 백그라운드 연락처 동기화 로직 (네이티브)
Future<void> performContactBackgroundSync() async {
  final stopwatch = Stopwatch()..start();
  log('[BackgroundSync] Starting contact sync (hash-based delta, native)...');

  const boxName = 'last_sync_state';
  if (!Hive.isBoxOpen(boxName)) {
    log('[BackgroundSync] Box \'$boxName\' is not open. Aborting sync.');
    return;
  }
  final Box stateBox = Hive.box(boxName);

  try {
    // 1. 네이티브 연락처 로드 및 해시 맵 생성
    List<Map<String, dynamic>> nativeContactsRaw;
    final stepWatch = Stopwatch()..start();
    try {
      nativeContactsRaw = await NativeMethods.getContacts();
      log(
        '[BackgroundSync] Reading ${nativeContactsRaw.length} native contacts took: ${stepWatch.elapsedMilliseconds}ms',
      );
      stepWatch.reset();
    } catch (e) {
      log('[BackgroundSync] Error getting native contacts: $e');
      return;
    }

    stepWatch.start();
    final Map<String, String> currentHashes = {};
    final Map<String, Map<String, dynamic>> currentContactsById = {};
    for (final contact in nativeContactsRaw) {
      final hash = _calculateNativeContactHash(contact);
      final id = contact['id']?.toString() ?? '';
      currentHashes[id] = hash;
      currentContactsById[id] = contact;
    }
    log(
      '[BackgroundSync] Calculating ${nativeContactsRaw.length} hashes took: ${stepWatch.elapsedMilliseconds}ms',
    );
    stepWatch.reset();

    // 2. 이전 상태 (해시 맵) 로드
    stepWatch.start();
    final previousStateData = stateBox.get(
      ContactsController._lastSyncStateKey,
    );
    Map<String, String> previousHashes = {};
    if (previousStateData != null) {
      try {
        if (previousStateData is String) {
          final decodedDynamicMap =
              jsonDecode(previousStateData) as Map<String, dynamic>;
          previousHashes = decodedDynamicMap.map(
            (key, value) => MapEntry(key, value as String),
          );
          log('[BackgroundSync] Loaded previous state from JSON string.');
        } else if (previousStateData is Map) {
          log(
            '[BackgroundSync] Warning: Loaded previous state directly as Map. Converting manually and resaving as JSON string.',
          );
          previousHashes = <String, String>{};
          previousStateData.forEach((key, value) {
            if (key is String && value is String) {
              previousHashes[key] = value;
            } else {
              log(
                '[BackgroundSync] Warning: Skipped invalid entry in stored map: key=[31m${key.runtimeType}[0m, value=${value.runtimeType}',
              );
            }
          });
          await stateBox.put(
            ContactsController._lastSyncStateKey,
            jsonEncode(previousHashes),
          );
        } else {
          log(
            '[BackgroundSync] Previous state has unexpected type: ${previousStateData.runtimeType}. Clearing state.',
          );
          await stateBox.delete(ContactsController._lastSyncStateKey);
        }
      } catch (e) {
        log('[BackgroundSync] Error processing previous contact hashes: $e');
        previousHashes = {};
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
      final prevHash = previousHashes[currentId];
      final currHash = currentHashes[currentId];
      if (!previousHashes.containsKey(currentId)) {
        log('[BackgroundSync][DIFF] 신규 연락처: $currentId, hash=$currHash');
        changedContactIds.add(currentId);
      } else if (prevHash != currHash) {
        log(
          '[BackgroundSync][DIFF] 변경 감지: $currentId, prevHash=$prevHash, currHash=$currHash',
        );
        changedContactIds.add(currentId);
      } else {
        log('[BackgroundSync][DIFF] 변경 없음: $currentId, hash=$currHash');
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
      if (contact != null &&
          (contact['phoneNumber'] ?? '').toString().isNotEmpty) {
        final normPhone = normalizePhone(
          (contact['phoneNumber'] ?? '').toString().trim(),
        );
        final name =
            (contact['displayName'] ?? '').toString().trim().isNotEmpty
                ? (contact['displayName'] ?? '').toString().trim()
                : '(No Name)';
        if (normPhone.isNotEmpty) {
          final lastUpdated = contact['lastUpdated'];
          final now = DateTime.now();
          final createdAt =
              lastUpdated != null
                  ? DateTime.fromMillisecondsSinceEpoch(
                    lastUpdated,
                    isUtc: true,
                  ).toIso8601String()
                  : now.toUtc().toIso8601String();

          log(
            '[BackgroundSync] Contact $name ($normPhone):\n'
            '  lastUpdated (millis): $lastUpdated\n'
            '  lastUpdated (KST): ${lastUpdated != null ? DateTime.fromMillisecondsSinceEpoch(lastUpdated).toLocal().toString() : "null"}\n'
            '  lastUpdated (UTC): ${lastUpdated != null ? DateTime.fromMillisecondsSinceEpoch(lastUpdated, isUtc: true).toString() : "null"}\n'
            '  현재시간 (KST): ${now.toLocal().toString()}\n'
            '  현재시간 (UTC): ${now.toUtc().toString()}\n'
            '  서버전송 (UTC ISO): $createdAt',
          );

          recordsToUpsert.add({
            'phoneNumber': normPhone,
            'name': name,
            'createdAt': createdAt,
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
      }
      stepWatch.stop();
    } else {
      log('[BackgroundSync] No contact changes detected.');
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
  final ContactRepository _contactRepository;
  List<PhoneBookModel> _contacts = [];
  Map<String, PhoneBookModel> _contactCache = {};
  bool _isLoading = false;
  DateTime? _lastLoadTime;
  static const String _lastSyncStateKey = 'contacts_state';

  ContactsController(this._contactRepository);

  /// 네이티브 연락처 목록 가져오기
  Future<List<PhoneBookModel>> getLocalContacts({
    bool forceRefresh = false,
  }) async {
    final now = DateTime.now();
    if (!forceRefresh &&
        _lastLoadTime != null &&
        now.difference(_lastLoadTime!) < const Duration(minutes: 1) &&
        _contacts.isNotEmpty) {
      log('[ContactsController] Using cached contacts.');
      return _contacts;
    }
    if (_isLoading) {
      log('[ContactsController] Already loading contacts...');
      return _contacts;
    }
    Future.microtask(() {
      if (!_isLoading) {
        _isLoading = true;
        notifyListeners();
      }
    });
    try {
      final nativeContacts = await NativeMethods.getContacts();
      final phoneBookModels = _parseNativeContacts(nativeContacts);
      for (var i = 0; i < phoneBookModels.length && i < 5; i++) {
        final c = phoneBookModels[i];
        log(
          '[ContactsController] Contact #$i: contactId=${c.contactId}, rawContactId=${c.rawContactId}, name=${c.name}, phone=${c.phoneNumber}',
        );
      }
      _contacts = phoneBookModels;
      _contactCache = {for (var c in _contacts) c.phoneNumber: c};
      _lastLoadTime = now;
      _isLoading = false;
      notifyListeners();
      return _contacts;
    } catch (e) {
      log('[ContactsController] Error fetching native contacts: $e');
      Future.microtask(() {
        _isLoading = false;
        notifyListeners();
      });
      throw e;
    }
  }

  void invalidateCache() {
    _contacts = [];
    _contactCache = {};
    _lastLoadTime = null;
    log('[ContactsController] Contacts cache invalidated.');
    notifyListeners();
  }

  List<PhoneBookModel> get contacts => _contacts;
  Map<String, PhoneBookModel> get contactCache => _contactCache;
  bool get isLoading => _isLoading;

  Future<String> getContactName(String phoneNumber) async {
    final normalizedNumber = normalizePhone(phoneNumber);
    if (_contactCache.containsKey(normalizedNumber)) {
      return _contactCache[normalizedNumber]!.name;
    }
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

  /// 네이티브 연락처 가져오기 테스트 (디버깅용)
  Future<void> getNativeContacts() async {
    log('[ContactsController] Testing native getContacts...');
    try {
      final contacts = await NativeMethods.getContacts();
      log('[ContactsController] Native contacts count: ${contacts.length}');
      for (var i = 0; i < contacts.length && i < 5; i++) {
        final contact = contacts[i];
        log(
          '''\n[ContactsController] Contact #$i:\n  ID: ${contact['id']}\n  DisplayName: ${contact['displayName']}\n  FirstName: ${contact['firstName']}\n  MiddleName: ${contact['middleName']}\n  LastName: ${contact['lastName']}\n  PhoneNumber: ${contact['phoneNumber']}\n  LastUpdated: ${contact['lastUpdated']}\n''',
        );
      }
    } catch (e) {
      log('[ContactsController] Error getting native contacts: $e');
    }
  }

  Future<void> refreshContacts() async {
    try {
      // 1. 로컬 저장소에서 기존 연락처 가져오기
      final List<PhoneBookModel> localContacts =
          await _contactRepository.getAllContacts();
      final Set<String> localKeys =
          localContacts.map((contact) => contact.contactId).toSet();

      // 2. 네이티브에서 최신 연락처 가져오기
      final contacts = await NativeMethods.getContacts();
      final phoneBookModels = _parseNativeContacts(contacts);

      // 3. 새로 추가된 연락처만 필터링
      final List<PhoneBookModel> newContacts =
          phoneBookModels
              .where((contact) => !localKeys.contains(contact.contactId))
              .toList();

      // 4. UI 업데이트
      _contacts = phoneBookModels;
      notifyListeners();

      // 5. 로컬 저장소 업데이트
      await _contactRepository.saveContacts(phoneBookModels);

      // 6. 새 연락처만 서버에 업로드
      if (newContacts.isNotEmpty) {
        log(
          '[ContactsController] Found ${newContacts.length} new contacts to upload',
        );
        try {
          final recordsToUpsert =
              newContacts
                  .map(
                    (contact) => {
                      'phoneNumber': contact.phoneNumber,
                      'name': contact.name,
                      'createdAt':
                          contact.createdAt?.toUtc().toIso8601String() ??
                          DateTime.now().toUtc().toIso8601String(),
                    },
                  )
                  .toList();

          await PhoneRecordsApi.upsertPhoneRecords(recordsToUpsert);
          log(
            '[ContactsController] Successfully uploaded new contacts to server',
          );
        } catch (e) {
          log('[ContactsController] Error uploading new contacts: $e');
        }
      } else {
        log('[ContactsController] No new contacts to upload');
      }
    } catch (e) {
      log('[ContactsController] Error refreshing contacts: $e');
    }
  }
}
