import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:developer';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:get_storage/get_storage.dart';
import 'package:mobile/graphql/phone_records_api.dart';
import 'package:mobile/models/phone_book_model.dart';
import 'package:mobile/utils/app_event_bus.dart';
import 'package:mobile/utils/constants.dart';

class ContactsController {
  final _box = GetStorage();
  static const storageKey = 'phonebook';

  // (A) 작업 큐
  final Queue<Function> _taskQueue = Queue();
  // (B) 실행 중 여부
  bool _busy = false;

  // 연락처 검색 최적화를 위한 인덱스
  Map<String, PhoneBookModel> _phoneToContactIndex = {};
  DateTime? _lastIndexUpdateTime;
  static const _indexCacheDuration = Duration(hours: 1);

  // 마지막 전체 동기화 시간
  DateTime? _lastFullSyncTime;
  static const _fullSyncInterval = Duration(hours: 1);

  // 전체 동기화가 필요한지 확인
  bool get _needsFullSync {
    if (_lastFullSyncTime == null) return true;
    return DateTime.now().difference(_lastFullSyncTime!) > _fullSyncInterval;
  }

  // 인덱스 유효성 검사
  bool get _isIndexValid {
    if (_lastIndexUpdateTime == null) return false;
    return DateTime.now().difference(_lastIndexUpdateTime!) <
        _indexCacheDuration;
  }

  // 인덱스 업데이트
  void _updateIndex(List<PhoneBookModel> contacts) {
    _phoneToContactIndex = {
      for (var contact in contacts) contact.phoneNumber: contact,
    };
    _lastIndexUpdateTime = DateTime.now();
  }

  // 전화번호로 연락처 빠르게 조회
  PhoneBookModel? getContactByPhone(String phoneNumber) {
    if (!_isIndexValid) {
      final contacts = _loadLocalPhoneBook();
      _updateIndex(contacts);
    }
    return _phoneToContactIndex[phoneNumber];
  }

  // 성능 측정을 위한 변수들
  DateTime? _lastSyncStartTime;
  DateTime? _lastSyncEndTime;
  int _totalContacts = 0;
  Map<String, int> _searchTimes = {};

  // 서버 연락처 캐시
  List<Map<String, dynamic>>? _serverContactsCache;
  DateTime? _lastServerCacheTime;
  static const _serverCacheDuration = Duration(hours: 4);
  static const _maxServerCacheSize = 10000;

  // 디바이스 연락처 캐시 추가
  List<Contact>? _deviceContactsCache;
  DateTime? _lastDeviceCacheTime;
  static const _deviceCacheDuration = Duration(hours: 2);
  static const _maxDeviceCacheSize = 10000;

  // 디바이스 연락처 캐시 유효성 검사
  bool get _isDeviceCacheValid {
    if (_lastDeviceCacheTime == null) return false;
    return DateTime.now().difference(_lastDeviceCacheTime!) <
        _deviceCacheDuration;
  }

  Future<List<Contact>> _getDeviceContacts() async {
    if (_isDeviceCacheValid && _deviceContactsCache != null) {
      log(
        '[ContactsController] Using cached device contacts (${_deviceContactsCache!.length} contacts)',
      );
      return _deviceContactsCache!;
    }

    final startTime = DateTime.now();
    final contacts = await FlutterContacts.getContacts(
      withProperties: true,
      withAccounts: true,
      withPhoto: true,
      withThumbnail: true,
      withGroups: false,
    );

    // 캐시 크기 제한 적용
    if (contacts.length <= _maxDeviceCacheSize) {
      _deviceContactsCache = contacts;
      _lastDeviceCacheTime = DateTime.now();
      log(
        '[ContactsController] Device contacts cached (${contacts.length} contacts)',
      );
    } else {
      log(
        '[ContactsController] Device contacts too large to cache (${contacts.length} contacts)',
      );
    }

    final duration = DateTime.now().difference(startTime).inMilliseconds;
    log(
      '[ContactsController] Device contacts fetch took: ${duration}ms (${contacts.length} contacts)',
    );
    return contacts;
  }

  Future<List<Map<String, dynamic>>> _getServerContacts() async {
    if (_isServerCacheValid && _serverContactsCache != null) {
      log(
        '[ContactsController] Using cached server contacts (${_serverContactsCache!.length} contacts)',
      );
      return _serverContactsCache!;
    }

    final startTime = DateTime.now();
    final contacts = await PhoneRecordsApi.getMyRecords();

    // 캐시 크기 제한 적용
    if (contacts.length <= _maxServerCacheSize) {
      _serverContactsCache = contacts;
      _lastServerCacheTime = DateTime.now();
      log(
        '[ContactsController] Server contacts cached (${contacts.length} contacts)',
      );
    } else {
      log(
        '[ContactsController] Server contacts too large to cache (${contacts.length} contacts)',
      );
    }

    final duration = DateTime.now().difference(startTime).inMilliseconds;
    log(
      '[ContactsController] Server contacts fetch took: ${duration}ms (${contacts.length} contacts)',
    );
    return contacts;
  }

  Future<void> syncContactsAll() async {
    if (!_needsFullSync) {
      log('[ContactsController] Skipping full sync - last sync was recent');
      return;
    }

    final completer = Completer<void>();
    _taskQueue.add(() async {
      try {
        final syncStartTime = DateTime.now();
        log('[ContactsController] syncContactsAll start...');

        // 서버와 디바이스 연락처를 병렬로 가져오기 (캐시 활용)
        final serverFuture = _getServerContacts();
        final deviceFuture = _getDeviceContacts();

        final results = await Future.wait([serverFuture, deviceFuture]);
        final serverList = results[0] as List<Map<String, dynamic>>;
        final deviceContacts = results[1] as List<Contact>;

        // 디바이스 연락처 처리 최적화
        final deviceStartTime = DateTime.now();
        final deviceList = await processContacts(deviceContacts);
        final deviceTime =
            DateTime.now().difference(deviceStartTime).inMilliseconds;
        log(
          '[ContactsController] Device contacts processed: ${deviceList.length} contacts (${deviceContacts.length - deviceList.length} skipped) in ${deviceTime}ms',
        );

        // 로컬 연락처 로드 - 캐시 사용
        final localStartTime = DateTime.now();
        final oldList = _loadLocalPhoneBook();
        final localTime =
            DateTime.now().difference(localStartTime).inMilliseconds;
        log(
          '[ContactsController] Local contacts load took: ${localTime}ms (${oldList.length} contacts)',
        );

        // 병합 최적화
        final mergeStartTime = DateTime.now();
        final merged = _mergeAll(
          serverList: serverList,
          deviceList: deviceList,
          oldList: oldList,
        );
        final mergeTime =
            DateTime.now().difference(mergeStartTime).inMilliseconds;
        log(
          '[ContactsController] Merge operation took: ${mergeTime}ms (${merged.length} total contacts)',
        );

        // diff 계산 및 서버 업로드 최적화
        final diffStartTime = DateTime.now();
        final diffList = _computeDiffForServer(merged, serverList);
        if (diffList.isNotEmpty) {
          log(
            '[ContactsController] Found ${diffList.length} differences to upload',
          );
          await _uploadDiff(diffList);
        } else {
          log(
            '[ContactsController] No differences found, skipping server update',
          );
        }
        final diffTime =
            DateTime.now().difference(diffStartTime).inMilliseconds;
        log(
          '[ContactsController] Diff computation and upload took: ${diffTime}ms',
        );

        // 로컬 저장 및 인덱스 업데이트
        final saveStartTime = DateTime.now();
        await _saveLocalPhoneBook(merged);
        _updateIndex(merged);
        _lastFullSyncTime = DateTime.now();
        appEventBus.fire(ContactsUpdatedEvent());
        final saveTime =
            DateTime.now().difference(saveStartTime).inMilliseconds;
        log(
          '[ContactsController] Local save and index update took: ${saveTime}ms',
        );

        final totalTime =
            DateTime.now().difference(syncStartTime).inMilliseconds;
        log('[ContactsController] Total sync completed in ${totalTime}ms');
        log('[ContactsController] Summary:');
        log('  - Server contacts: ${serverList.length}');
        log(
          '  - Device contacts: ${deviceList.length} (${deviceContacts.length - deviceList.length} skipped)',
        );
        log('  - Local contacts: ${oldList.length}');
        log('  - Merged contacts: ${merged.length}');
        log('  - Differences: ${diffList.length}');

        completer.complete();
      } catch (e, st) {
        log('[ContactsController] syncContactsAll error: $e\n$st');
        completer.completeError(e, st);
      }
    });

    _processQueue();
    return completer.future;
  }

  /// 내부: 큐 처리
  void _processQueue() {
    if (_busy) return;
    if (_taskQueue.isEmpty) return;

    _busy = true;
    final task = _taskQueue.removeFirst();

    Future(() async {
      await task();
      _busy = false;
      if (_taskQueue.isNotEmpty) {
        _processQueue();
      }
    });
  }

  /// 외부에서 "현재 로컬 저장된 연락처" 조회
  List<PhoneBookModel> getSavedContacts() {
    if (!_isIndexValid) {
      final contacts = _loadLocalPhoneBook();
      _updateIndex(contacts);
    }
    return _phoneToContactIndex.values.toList();
  }

  /// 로컬에 메모/타입/이름 등이 반영된 레코드 업데이트
  /// => 이후 syncContactsAll() 하면 서버도 업서트
  Future<void> addOrUpdateLocalRecord(PhoneBookModel newItem) async {
    final startTime = DateTime.now();
    final list = _loadLocalPhoneBook();
    final idx = list.indexWhere((e) => e.phoneNumber == newItem.phoneNumber);
    if (idx >= 0) {
      list[idx] = newItem;
    } else {
      list.add(newItem);
    }
    await _saveLocalPhoneBook(list);

    final endTime = DateTime.now();
    log(
      '[ContactsController] addOrUpdateLocalRecord took: ${endTime.difference(startTime).inMilliseconds}ms',
    );
    _updateIndex(list);

    // 서버에 단일 연락처만 업데이트
    await _uploadDiff([newItem]);

    // 연락처 수정 후 이벤트 발생
    appEventBus.fire(ContactsUpdatedEvent());
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

    // 1. 내 폰에 있는 번호만 처리
    for (var entry in deviceMap.entries) {
      final phone = entry.key;
      final deviceItem = entry.value;
      final serverItem = serverMap[phone];
      final oldItem = oldMap[phone];

      // 2. 내 폰에 있는 번호의 메모/타입이 없는 경우 서버에서 가져옴
      final oldMemo = oldItem?.memo ?? '';
      final oldType = oldItem?.type ?? 0;
      final serverMemo = serverItem?['memo'] as String? ?? '';
      final serverType = serverItem?['type'] as int? ?? 0;

      final finalMemo =
          oldMemo.isNotEmpty
              ? oldMemo
              : (serverMemo.isNotEmpty ? serverMemo : '');
      final finalType =
          oldType != 0 ? oldType : (serverType != 0 ? serverType : 0);

      // 3. 내 폰의 이름이 서버와 다르면 내 폰 이름으로 업데이트
      final serverName = serverItem?['name'] as String? ?? '';
      final finalName =
          deviceItem.name != serverName ? deviceItem.name : serverName;

      mergedSet.add(
        PhoneBookModel(
          contactId: deviceItem.contactId,
          name: finalName,
          phoneNumber: phone,
          memo: finalMemo.isNotEmpty ? finalMemo : null,
          type: finalType != 0 ? finalType : null,
          updatedAt: oldItem?.updatedAt,
        ),
      );
    }

    // 4. 내 폰에만 있고 서버에는 없는 번호는 초기값으로 서버에 올림
    for (var entry in deviceMap.entries) {
      final phone = entry.key;
      if (!serverMap.containsKey(phone)) {
        final deviceItem = entry.value;
        mergedSet.add(
          PhoneBookModel(
            contactId: deviceItem.contactId,
            name: deviceItem.name,
            phoneNumber: phone,
            memo: null,
            type: null,
            updatedAt: DateTime.now().toUtc().toIso8601String(),
          ),
        );
      }
    }

    return mergedSet.toList();
  }

  /// diff => 서버 업서트
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
            'createdAt':
                m.updatedAt ?? DateTime.now().toUtc().toIso8601String(),
          };
        }).toList();

    await PhoneRecordsApi.upsertPhoneRecords(records);
  }

  Future<void> _saveLocalPhoneBook(List<PhoneBookModel> list) async {
    final raw = jsonEncode(list.map((e) => e.toJson()).toList());
    await _box.write(storageKey, raw);
  }

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

  // 성능 측정을 위한 헬퍼 메서드
  void _measureSearchTime(String phoneNumber, Function searchFunction) {
    final startTime = DateTime.now();
    searchFunction();
    final endTime = DateTime.now();
    final duration = endTime.difference(startTime).inMilliseconds;
    _searchTimes[phoneNumber] = duration;
    log('[ContactsController] Search for $phoneNumber took: ${duration}ms');
  }

  // 성능 통계 출력
  void printPerformanceStats() {
    log('[ContactsController] Performance Stats:');
    log('Total contacts: $_totalContacts');
    if (_lastSyncStartTime != null && _lastSyncEndTime != null) {
      log(
        'Last sync duration: ${_lastSyncEndTime!.difference(_lastSyncStartTime!).inMilliseconds}ms',
      );
    }
    if (_searchTimes.isNotEmpty) {
      log('Search times:');
      _searchTimes.forEach((phone, time) {
        log('  $phone: ${time}ms');
      });
    }
  }

  // 전화 종료 후 콜로그만 업데이트
  Future<void> updateCallLog(String phoneNumber) async {
    final contact = getContactByPhone(phoneNumber);
    if (contact != null) {
      await addOrUpdateLocalRecord(contact);
    }
  }

  // 서버 연락처 캐시 유효성 검사
  bool get _isServerCacheValid {
    if (_lastServerCacheTime == null) return false;
    return DateTime.now().difference(_lastServerCacheTime!) <
        _serverCacheDuration;
  }

  // 연락처 처리 공통 메서드
  Future<List<PhoneBookModel>> processContacts(List<Contact> contacts) async {
    final startTime = DateTime.now();
    final deviceList = <PhoneBookModel>[];
    final batchSize = 1000;
    final futures = <Future<void>>[];

    // 모든 연락처를 병렬로 처리
    for (var i = 0; i < contacts.length; i += batchSize) {
      final end =
          (i + batchSize < contacts.length) ? i + batchSize : contacts.length;
      final batch = contacts.sublist(i, end);

      futures.add(
        Future(() {
          for (final c in batch) {
            if (c.phones.isEmpty) continue;
            final rawPhone = c.phones.first.number.trim();
            if (rawPhone.isEmpty) continue;

            final normPhone = normalizePhone(rawPhone);
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
        }),
      );
    }

    await Future.wait(futures);
    final processTime = DateTime.now().difference(startTime).inMilliseconds;
    log(
      '[ContactsController] Contacts processed: ${deviceList.length} contacts (${contacts.length - deviceList.length} skipped) in ${processTime}ms',
    );

    return deviceList;
  }

  /// 여러 전화번호에 대한 연락처를 한 번에 조회
  Map<String, PhoneBookModel> getContactsByPhones(List<String> phoneNumbers) {
    final stopwatch = Stopwatch()..start();
    final contacts = getSavedContacts();
    final result = <String, PhoneBookModel>{};

    // 전화번호 정규화 캐시
    final normalizedCache = <String, String>{};

    // 연락처 전화번호 정규화 캐시
    final contactNormalizedCache = <String, String>{};

    // 전화번호 정규화
    for (final phone in phoneNumbers) {
      normalizedCache[phone] = normalizePhone(phone);
    }

    // 연락처 처리
    for (final contact in contacts) {
      final phoneStr = contact.phoneNumber ?? '';
      final normPhone = contactNormalizedCache.putIfAbsent(
        phoneStr,
        () => normalizePhone(phoneStr),
      );

      // 매칭된 전화번호 찾기
      for (final entry in normalizedCache.entries) {
        if (entry.value == normPhone) {
          result[entry.key] = contact;
          break;
        }
      }
    }

    stopwatch.stop();
    debugPrint(
      '[ContactsController] Batch contact lookup took: ${stopwatch.elapsedMilliseconds}ms for ${phoneNumbers.length} numbers (${result.length} found)',
    );

    return result;
  }
}
