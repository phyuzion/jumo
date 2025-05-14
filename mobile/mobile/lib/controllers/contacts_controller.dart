import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:hive_ce/hive.dart';
import 'package:mobile/graphql/phone_records_api.dart';
import 'package:mobile/models/phone_book_model.dart';
import 'package:mobile/utils/constants.dart';
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

class ContactsController with ChangeNotifier {
  final ContactRepository _contactRepository;
  List<PhoneBookModel> _contacts = [];
  Map<String, PhoneBookModel> _contactCache = {};
  bool _isLoading = false;
  DateTime? _lastLoadTime;

  ContactsController(this._contactRepository);

  /// 네이티브 연락처 목록 가져오기
  Future<List<PhoneBookModel>> getLocalContacts({
    bool forceRefresh = false,
  }) async {
    final overallStopwatch = Stopwatch()..start(); // 전체 시간 측정 시작
    log(
      '[ContactsController][PERF] getLocalContacts started at ${DateTime.now().toIso8601String()}',
    );

    final now = DateTime.now();
    if (!forceRefresh &&
        _lastLoadTime != null &&
        now.difference(_lastLoadTime!) < const Duration(minutes: 1) &&
        _contacts.isNotEmpty) {
      log('[ContactsController] Using cached contacts.');
      overallStopwatch.stop();
      log(
        '[ContactsController][PERF] getLocalContacts finished (cached) in ${overallStopwatch.elapsedMilliseconds}ms',
      );
      return _contacts;
    }
    if (_isLoading) {
      log('[ContactsController] Already loading contacts...');
      overallStopwatch.stop();
      log(
        '[ContactsController][PERF] getLocalContacts finished (already loading) in ${overallStopwatch.elapsedMilliseconds}ms',
      );
      return _contacts;
    }

    Future.microtask(() {
      if (!_isLoading) {
        _isLoading = true;
        notifyListeners();
      }
    });

    final stopwatch = Stopwatch(); // 단계별 시간 측정용

    try {
      log(
        '[ContactsController][PERF] Step 1: Loading local contacts from repository...',
      );
      stopwatch.start();
      final List<PhoneBookModel> localContacts =
          await _contactRepository.getAllContacts();
      stopwatch.stop();
      log(
        '[ContactsController][PERF] Step 1 finished in ${stopwatch.elapsedMilliseconds}ms. Found ${localContacts.length} local contacts.',
      );
      stopwatch.reset();

      final Map<String, PhoneBookModel> localMap = {
        for (var c in localContacts) c.contactId: c,
      };

      log(
        '[ContactsController][PERF] Step 2: Fetching contacts from native...',
      );
      stopwatch.start();
      final nativeContacts = await NativeMethods.getContacts();
      stopwatch.stop();
      log(
        '[ContactsController][PERF] Step 2 finished in ${stopwatch.elapsedMilliseconds}ms. Fetched ${nativeContacts.length} contacts from native.',
      );
      stopwatch.reset();

      log('[ContactsController][PERF] Step 3: Parsing native contacts...');
      stopwatch.start();
      final phoneBookModels = _parseNativeContacts(nativeContacts);
      stopwatch.stop();
      log(
        '[ContactsController][PERF] Step 3 finished in ${stopwatch.elapsedMilliseconds}ms. Parsed into ${phoneBookModels.length} PhoneBookModels.',
      );
      stopwatch.reset();

      log('[ContactsController][PERF] Step 4: Filtering changed contacts...');
      stopwatch.start();
      final List<PhoneBookModel> changedContacts =
          phoneBookModels.where((contact) {
            final local = localMap[contact.contactId];
            if (local == null) {
              return true; // 신규
            }
            final isChanged =
                local.name != contact.name ||
                local.phoneNumber != contact.phoneNumber ||
                local.rawContactId != contact.rawContactId ||
                (local.createdAt?.millisecondsSinceEpoch !=
                    contact
                        .createdAt
                        ?.millisecondsSinceEpoch); // DateTime 비교 수정
            // if (isChanged) { ... 상세 로그는 필요시 활성화 ... }
            return isChanged;
          }).toList();
      stopwatch.stop();
      log(
        '[ContactsController][PERF] Step 4 finished in ${stopwatch.elapsedMilliseconds}ms. Found ${changedContacts.length} changed contacts.',
      );
      stopwatch.reset();

      log('[ContactsController][PERF] Updating in-memory cache and state...');
      _contacts = phoneBookModels;
      _contactCache = {for (var c in _contacts) c.phoneNumber: c};
      _lastLoadTime = now; // 이 시점은 모든 데이터 처리가 끝난 후가 더 적합할 수 있음
      // _isLoading = false; // notifyListeners는 finally에서 한번만
      // notifyListeners();
      log('[ContactsController][PERF] In-memory cache updated.');

      log(
        '[ContactsController][PERF] Step 5: Saving all contacts to local repository...',
      );
      stopwatch.start();
      await _contactRepository.saveContacts(phoneBookModels);
      stopwatch.stop();
      log(
        '[ContactsController][PERF] Step 5 finished in ${stopwatch.elapsedMilliseconds}ms.',
      );
      stopwatch.reset();

      if (changedContacts.isNotEmpty) {
        log(
          '[ContactsController][PERF] Step 6: Preparing to upload ${changedContacts.length} changed contacts to server (async)...',
        );
        Future(() async {
          final uploadStopwatch = Stopwatch()..start();
          log(
            '[ContactsController][PERF][UploadTask] Started at ${DateTime.now().toIso8601String()}',
          );
          try {
            final recordsToUpsert =
                changedContacts
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
            uploadStopwatch.stop();
            log(
              '[ContactsController][PERF][UploadTask] Successfully uploaded in ${uploadStopwatch.elapsedMilliseconds}ms.',
            );
          } catch (e, stackTrace) {
            uploadStopwatch.stop();
            log(
              '[ContactsController][PERF][UploadTask] Error uploading contacts in ${uploadStopwatch.elapsedMilliseconds}ms: $e',
            );
            log('[ContactsController] Stack trace: $stackTrace');
          }
        });
      } else {
        log(
          '[ContactsController][PERF] Step 6: No contacts to upload to server.',
        );
      }

      overallStopwatch.stop();
      log(
        '[ContactsController][PERF] getLocalContacts finished successfully in ${overallStopwatch.elapsedMilliseconds}ms',
      );
      return _contacts;
    } catch (e, stackTrace) {
      // stackTrace 추가
      log('[ContactsController] Error in getLocalContacts: $e');
      log(
        '[ContactsController] Stack trace for error: $stackTrace',
      ); // 에러 발생 시 스택 트레이스 로깅
      overallStopwatch.stop();
      log(
        '[ContactsController][PERF] getLocalContacts finished with error in ${overallStopwatch.elapsedMilliseconds}ms',
      );
      // _isLoading = false; // notifyListeners는 finally에서
      // notifyListeners();
      rethrow; // finally에서 notifyListeners를 호출하므로 여기서는 rethrow만
    } finally {
      Future.microtask(() {
        _isLoading = false;
        notifyListeners(); // 로딩 완료 또는 에러 발생 시 UI 업데이트
        log(
          '[ContactsController][PERF] Executed finally block. isLoading: $_isLoading',
        );
      });
    }
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

  Future<void> refreshContacts() async {
    log('[ContactsController] refreshContacts started');
    _isLoading = true;
    notifyListeners();
    _isLoading = false;

    // 백그라운드에서 getLocalContacts 호출
    Future(() async {
      try {
        await getLocalContacts(forceRefresh: true);
      } catch (e, stackTrace) {
        log('[ContactsController] Error refreshing contacts: $e');
        log('[ContactsController] Stack trace: $stackTrace');
      }
    });
  }
}
