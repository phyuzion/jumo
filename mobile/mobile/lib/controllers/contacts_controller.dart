import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:developer';

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
  static const _indexCacheDuration = Duration(minutes: 5);

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

  Future<void> syncContactsAll() async {
    final completer = Completer<void>();
    _taskQueue.add(() async {
      try {
        _lastSyncStartTime = DateTime.now();
        log('[ContactsController] syncContactsAll start...');

        // 1) 서버 목록
        final serverStartTime = DateTime.now();
        final serverList = await PhoneRecordsApi.getMyRecords();
        log(
          '[ContactsController] Server contacts fetch took: ${DateTime.now().difference(serverStartTime).inMilliseconds}ms',
        );

        // 2) 기기 연락처 목록
        final deviceStartTime = DateTime.now();
        final deviceContacts = await FlutterContacts.getContacts(
          withProperties: true,
          withAccounts: true,
          withPhoto: true,
          withThumbnail: true,
          withGroups: false,
        );
        log(
          '[ContactsController] Device contacts fetch took: ${DateTime.now().difference(deviceStartTime).inMilliseconds}ms',
        );

        final deviceList = <PhoneBookModel>[];
        for (final c in deviceContacts) {
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
        _totalContacts = deviceList.length;
        log('[ContactsController] Total contacts processed: $_totalContacts');

        // 3) 기존 로컬
        final localStartTime = DateTime.now();
        final oldList = _loadLocalPhoneBook();
        log(
          '[ContactsController] Local contacts load took: ${DateTime.now().difference(localStartTime).inMilliseconds}ms',
        );

        // 4) 병합
        final mergeStartTime = DateTime.now();
        final merged = _mergeAll(
          serverList: serverList,
          deviceList: deviceList,
          oldList: oldList,
        );
        log(
          '[ContactsController] Merge operation took: ${DateTime.now().difference(mergeStartTime).inMilliseconds}ms',
        );

        // 5) diff => 서버 업서트
        final diffStartTime = DateTime.now();
        final diffList = _computeDiffForServer(merged, serverList);
        if (diffList.isNotEmpty) {
          log('[ContactsController] found ${diffList.length} diff => upsert');
          await _uploadDiff(diffList);
        } else {
          log('[ContactsController] no diff => skip upsert');
        }
        log(
          '[ContactsController] Diff computation and upload took: ${DateTime.now().difference(diffStartTime).inMilliseconds}ms',
        );

        // 6) 로컬 저장 + 인덱스 업데이트 + 이벤트
        final saveStartTime = DateTime.now();
        await _saveLocalPhoneBook(merged);
        _updateIndex(merged);
        appEventBus.fire(ContactsUpdatedEvent());
        log(
          '[ContactsController] Local save took: ${DateTime.now().difference(saveStartTime).inMilliseconds}ms',
        );

        _lastSyncEndTime = DateTime.now();
        final totalTime = _lastSyncEndTime!.difference(_lastSyncStartTime!);
        log(
          '[ContactsController] Total sync time: ${totalTime.inMilliseconds}ms',
        );

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
}
