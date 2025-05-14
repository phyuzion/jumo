import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:mobile/models/phone_book_model.dart';
import 'package:mobile/repositories/contact_repository.dart';
import 'package:mobile/services/native_methods.dart';
import 'package:mobile/utils/constants.dart';
import 'package:mobile/graphql/phone_records_api.dart';

// 네이티브 연락처 파싱 함수
List<PhoneBookModel> _parseNativeContacts(
  List<Map<String, dynamic>> contactsRawData,
) {
  final List<PhoneBookModel> result = [];
  for (final c in contactsRawData) {
    final rawPhone = (c['phoneNumber'] ?? '').toString().trim();
    if (rawPhone.isEmpty) continue;
    final normPhone = normalizePhone(rawPhone);
    // 네이티브에서 전달되는 이름 필드를 모두 활용하도록 수정
    String displayName = (c['displayName'] ?? '').toString().trim();
    String firstName = (c['firstName'] ?? '').toString().trim();
    String middleName = (c['middleName'] ?? '').toString().trim();
    String lastName = (c['lastName'] ?? '').toString().trim();

    // displayName이 비어있으면 다른 이름 필드를 조합하여 생성 시도
    if (displayName.isEmpty) {
      List<String> nameParts = [];
      if (firstName.isNotEmpty) nameParts.add(firstName);
      if (middleName.isNotEmpty) nameParts.add(middleName);
      if (lastName.isNotEmpty) nameParts.add(lastName);
      displayName = nameParts.join(' ').trim();
    }
    if (displayName.isEmpty) {
      displayName = '(No Name)';
    }

    dynamic lastUpdatedValue = c['lastUpdated'];
    DateTime? parsedCreatedAt;
    if (lastUpdatedValue is int) {
      parsedCreatedAt = DateTime.fromMillisecondsSinceEpoch(
        lastUpdatedValue,
        isUtc: true,
      );
    } else if (lastUpdatedValue is String) {
      parsedCreatedAt = DateTime.tryParse(lastUpdatedValue);
    }

    result.add(
      PhoneBookModel(
        contactId: c['id']?.toString() ?? '',
        rawContactId: c['rawId']?.toString(),
        name: displayName, // 최종 결정된 displayName 사용
        // 개별 이름 필드도 모델에 저장하려면 PhoneBookModel에 필드 추가 필요
        // firstName: firstName,
        // lastName: lastName,
        phoneNumber: normPhone,
        createdAt: parsedCreatedAt,
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
  bool _isSyncing = false;
  DateTime? _lastFullSyncTime;
  StreamSubscription<List<Map<String, dynamic>>>? _contactsStreamSubscription;
  bool _initialLoadAttempted = false; // 초기 로드 시도 여부 플래그

  ContactsController(this._contactRepository) {
    log(
      '[ContactsController] Instance created. Initial load to be triggered externally.',
    );
  }

  List<PhoneBookModel> get contacts => List.unmodifiable(_contacts);
  Map<String, PhoneBookModel> get contactCache =>
      Map.unmodifiable(_contactCache);
  bool get isLoading => _isLoading;
  bool get isSyncing => _isSyncing;
  bool get initialLoadAttempted => _initialLoadAttempted; // 외부에서 확인 가능하도록

  Future<void> loadInitialContacts() async {
    log('[ContactsController] loadInitialContacts called.');
    if (_isSyncing || _initialLoadAttempted) {
      // 이미 동기화 중이거나, 초기 로드가 이미 시도되었다면 중복 실행 방지
      log(
        '[ContactsController] Already syncing or initial load attempted, skipping initial load. isSyncing: $_isSyncing, initialLoadAttempted: $_initialLoadAttempted',
      );
      return;
    }
    _initialLoadAttempted = true; // 로드 시도 플래그 설정
    _isLoading = true;
    notifyListeners();

    List<PhoneBookModel> cachedContactsForDiff = [];
    try {
      cachedContactsForDiff = await _contactRepository.getAllContacts();
      if (cachedContactsForDiff.isNotEmpty) {
        _contacts = List.from(cachedContactsForDiff);
        _updateContactCache();
        log(
          '[ContactsController] Loaded ${cachedContactsForDiff.length} contacts from Hive cache for initial display.',
        );
      }
    } catch (e, s) {
      log(
        '[ContactsController] Error loading contacts from Hive for initial display: $e',
        stackTrace: s,
      );
      _contacts = [];
      _contactCache = {};
    } finally {
      // 이 시점에서는 UI가 캐시된 데이터로 먼저 그려질 수 있도록 isLoading을 false로 할 수 있으나,
      // 전체 동기화가 아직 시작 전이므로, _startFullContactsSync에서 isLoading을 다시 관리.
      // 여기서는 notifyListeners()만 호출하여 캐시 로드 결과를 반영.
      notifyListeners();
    }
    // clearPreviousContacts는 항상 false로 전달 (캐시와 비교하여 diff 업로드 위함)
    // 또는, 앱 첫 실행 시에는 서버에 데이터가 없을 수 있으므로 clearPreviousContacts:true (모두 업로드) 전략도 가능
    await _startFullContactsSync(
      clearPreviousContacts: _contacts.isEmpty,
      originalContactsForDiff: cachedContactsForDiff,
    );
  }

  Future<void> refreshContacts({bool force = false}) async {
    log('[ContactsController] refreshContacts(force: $force) called');
    if (!_initialLoadAttempted && !force) {
      log(
        '[ContactsController] Initial load not attempted yet. Calling loadInitialContacts instead of refresh(force:false).',
      );
      await loadInitialContacts(); // 초기 로드가 안됐으면 refresh(force:false)도 초기 로드처럼 동작
      return;
    }
    if (!force && _isSyncing) {
      log(
        '[ContactsController] Already syncing and not a forced refresh, refresh skipped.',
      );
      return;
    }
    if (force || !_isSyncing) {
      List<PhoneBookModel> currentContactsForDiff = List.from(_contacts);
      await _startFullContactsSync(
        clearPreviousContacts: force,
        originalContactsForDiff: currentContactsForDiff,
      );
    } else {
      log(
        '[ContactsController] Syncing is already in progress, not starting new one unless forced.',
      );
    }
  }

  Future<void> _startFullContactsSync({
    required bool clearPreviousContacts,
    required List<PhoneBookModel> originalContactsForDiff,
  }) async {
    if (_isSyncing) {
      log(
        '[ContactsController] _startFullContactsSync: Already syncing. Aborting this call.',
      );
      return;
    }
    _isSyncing = true;
    _isLoading = true;
    notifyListeners();

    log(
      '[ContactsController] _startFullContactsSync: Starting full sync (clearPrevious: $clearPreviousContacts).',
    );

    List<PhoneBookModel> newContactListForThisSync = [];
    if (clearPreviousContacts) {
      _contacts = [];
      _contactCache = {};
      notifyListeners();
    }

    await _contactsStreamSubscription?.cancel();
    _contactsStreamSubscription = null;

    try {
      _contactsStreamSubscription = NativeMethods.getContactsStream().listen(
        (List<Map<String, dynamic>> chunkData) {
          if (chunkData.isEmpty && newContactListForThisSync.isEmpty) {
            log('[ContactsController] Stream: Received initial empty chunk.');
          }

          final List<PhoneBookModel> parsedChunk = _parseNativeContacts(
            chunkData,
          );
          if (parsedChunk.isNotEmpty) {
            newContactListForThisSync.addAll(parsedChunk);
            log(
              '[ContactsController] Stream: Received and parsed chunk of ${parsedChunk.length}. Total for this sync: ${newContactListForThisSync.length}',
            );
            // 점진적 UI 업데이트 (clearPreviousContacts가 false일 때만 의미있음, 현재는 onDone에서 한번에 업데이트)
            if (!clearPreviousContacts) {
              // 기존 _contacts에 parsedChunk를 합치고, 중복 제거 및 정렬 후 _contacts 업데이트 및 notifyListeners()
              // 이 부분은 UX를 위해 중요하지만, 지금은 onDone에서 전체 업데이트로 단순화.
            }
          }
        },
        onError: (error, stackTrace) {
          log(
            '[ContactsController] Error in contacts stream: $error',
            stackTrace: stackTrace,
          );
          _finishSync(isSuccess: false);
        },
        onDone: () async {
          log(
            '[ContactsController] Contacts stream done. Total contacts received: ${newContactListForThisSync.length}.',
          );
          await _handleSyncCompletion(
            newContactListForThisSync,
            originalContactsForDiff,
            clearPreviousContacts,
          );
        },
      );
    } catch (e, s) {
      log(
        '[ContactsController] Error starting contacts stream: $e',
        stackTrace: s,
      );
      _finishSync(isSuccess: false);
    }
  }

  Future<void> _handleSyncCompletion(
    List<PhoneBookModel> newContactsFromSync,
    List<PhoneBookModel> originalContacts,
    bool wasCleared,
  ) async {
    _contacts = List.from(newContactsFromSync);
    _updateContactCache();
    _lastFullSyncTime = DateTime.now();

    log(
      '[ContactsController] Saving ${_contacts.length} contacts to Hive (on main isolate)...',
    );
    try {
      final saveStopwatch = Stopwatch()..start();
      await _contactRepository.saveContacts(_contacts);
      saveStopwatch.stop();
      log(
        '[ContactsController] Saved contacts to Hive (on main isolate) in ${saveStopwatch.elapsedMilliseconds}ms.',
      );

      log('[ContactsController] Preparing contacts for server upload...');
      List<PhoneBookModel> contactsToUpload = [];

      if (wasCleared || originalContacts.isEmpty) {
        contactsToUpload = List.from(newContactsFromSync);
        log(
          '[ContactsController] Uploading all ${contactsToUpload.length} contacts (wasCleared: $wasCleared, originalEmpty: ${originalContacts.isEmpty}).',
        );
      } else {
        final Map<String, PhoneBookModel> originalContactsMap = {
          for (var c in originalContacts) c.contactId: c,
        };
        for (var newContact in newContactsFromSync) {
          final PhoneBookModel? originalContact =
              originalContactsMap[newContact.contactId];
          bool changed = false;
          if (originalContact == null) {
            changed = true;
          } else {
            bool nameChanged = originalContact.name != newContact.name;
            bool phoneChanged =
                normalizePhone(originalContact.phoneNumber) !=
                normalizePhone(newContact.phoneNumber);
            bool timestampChanged =
                (originalContact.createdAt?.millisecondsSinceEpoch ?? 0) !=
                (newContact.createdAt?.millisecondsSinceEpoch ?? 0);
            if (nameChanged || phoneChanged || timestampChanged) {
              changed = true;
            }
          }
          if (changed) {
            contactsToUpload.add(newContact);
          }
        }
        log(
          '[ContactsController] Found ${contactsToUpload.length} changed/new contacts to upload based on diff.',
        );
      }

      if (contactsToUpload.isNotEmpty) {
        final recordsToUpsert =
            contactsToUpload.map((contact) {
              Map<String, dynamic> serverMap = {
                'phoneNumber': normalizePhone(contact.phoneNumber),
                'name': contact.name,
              };
              if (contact.createdAt != null) {
                serverMap['createdAt'] =
                    contact.createdAt!.toUtc().toIso8601String();
              }
              return serverMap;
            }).toList();

        log(
          '[ContactsController] Uploading ${recordsToUpsert.length} records to server (createdAt as UTC ISO8601 string)...',
        );
        try {
          await PhoneRecordsApi.upsertPhoneRecords(recordsToUpsert);
          log('[ContactsController] Successfully uploaded contacts to server.');
        } catch (e, s) {
          log(
            '[ContactsController] Error uploading contacts to server: $e',
            stackTrace: s,
          );
        }
      } else {
        log('[ContactsController] No contacts to upload to server.');
      }
    } catch (e, s) {
      log(
        '[ContactsController] Error in _handleSyncCompletion (Hive save or server prep): $e',
        stackTrace: s,
      );
    } finally {
      _finishSync(isSuccess: true);
    }
  }

  void _finishSync({required bool isSuccess}) {
    _isSyncing = false;
    _isLoading = false;
    notifyListeners();
    log('[ContactsController] Sync finished. Success: $isSuccess');
  }

  void _updateContactCache() {
    _contactCache = {for (var c in _contacts) normalizePhone(c.phoneNumber): c};
    log(
      '[ContactsController] Contact cache updated with ${_contactCache.length} entries.',
    );
  }

  Future<String> getContactName(String phoneNumber) async {
    final normalizedNumber = normalizePhone(phoneNumber);
    if (_contactCache.containsKey(normalizedNumber)) {
      return _contactCache[normalizedNumber]!.name;
    }
    try {
      final contact = _contacts.firstWhere(
        (c) => normalizePhone(c.phoneNumber) == normalizedNumber,
      );
      return contact.name;
    } catch (e) {
      return '';
    }
  }

  @override
  void dispose() {
    log('[ContactsController] dispose called. Cancelling stream subscription.');
    _contactsStreamSubscription?.cancel();
    super.dispose();
  }
}
