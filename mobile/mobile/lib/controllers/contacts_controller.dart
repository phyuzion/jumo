import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:mobile/models/phone_book_model.dart';
import 'package:mobile/repositories/contact_repository.dart';
import 'package:mobile/services/native_methods.dart';
import 'package:mobile/utils/constants.dart';
import 'package:mobile/graphql/phone_records_api.dart';
import 'package:mobile/repositories/settings_repository.dart';

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
  final SettingsRepository _settingsRepository;
  List<PhoneBookModel> _contacts = [];
  Map<String, PhoneBookModel> _contactCache = {};
  bool _isLoading = false;
  bool _isSyncing = false;
  StreamSubscription<List<Map<String, dynamic>>>? _contactsStreamSubscription;
  bool _initialLoadAttempted = false; // 초기 로드 시도 여부 플래그

  ContactsController(this._contactRepository, this._settingsRepository) {
    log(
      '[ContactsController] Instance created. Initial sync to be triggered externally.',
    );
  }

  List<PhoneBookModel> get contacts => List.unmodifiable(_contacts);
  Map<String, PhoneBookModel> get contactCache =>
      Map.unmodifiable(_contactCache);
  bool get isLoading => _isLoading;
  bool get isSyncing => _isSyncing;
  bool get initialLoadAttempted => _initialLoadAttempted; // 외부에서 확인 가능하도록

  Future<void> syncContacts({bool forceFullSync = false}) async {
    if (_isSyncing) {
      log('[ContactsController.syncContacts] Already syncing. Skipping.');
      return;
    }

    _isSyncing = true;
    _isLoading = true;
    if (!_initialLoadAttempted || forceFullSync) {
      // 첫 로드 시도거나 강제 전체 동기화 시에만 UI 즉시 업데이트
      notifyListeners();
    }

    // _contacts가 비어있고, 강제 전체 동기화가 아니며, 이전 동기화 시간이 있는 경우 (델타 동기화 시나리오),
    // Hive에서 기존 연락처를 로드하여 originalContactsForDiff의 기준을 설정합니다.
    // 이는 앱 재시작 후 컨트롤러가 새로 생성되었지만 Hive에는 데이터가 있는 경우를 처리합니다.
    if (_contacts.isEmpty && !forceFullSync) {
      final int? previousSyncTimestamp =
          await _settingsRepository.getLastContactsSyncTimestamp();
      if (previousSyncTimestamp != null && previousSyncTimestamp > 0) {
        try {
          final List<PhoneBookModel> existingContactsFromHive =
              await _contactRepository.getAllContacts();
          if (existingContactsFromHive.isNotEmpty) {
            _contacts = List.from(existingContactsFromHive);
            _updateContactCache(); // 캐시도 업데이트
          } else {
            log(
              '[ContactsController.syncContacts] Hive was empty. Proceeding with delta sync against an empty baseline.',
            );
          }
        } catch (e, s) {
          log(
            '[ContactsController.syncContacts] Error loading from Hive for baseline: $e',
            stackTrace: s,
          );
          // 오류 발생 시 빈 _contacts로 진행 (기존 로직과 유사하게)
        }
      }
    }

    List<PhoneBookModel> originalContactsForDiff = List.from(
      _contacts,
    ); // 현재 메모리 상태 백업 (Hive에서 로드된 후의 상태일 수 있음)
    bool performClearForFullSync = forceFullSync; // 강제 전체 동기화 시에는 기존 데이터를 지움
    int? lastSyncTimestamp;

    if (!forceFullSync) {
      // 강제 전체 동기화가 아닐 경우에만 마지막 동기화 시간 조회
      lastSyncTimestamp =
          await _settingsRepository.getLastContactsSyncTimestamp();
      if (lastSyncTimestamp == null || lastSyncTimestamp == 0) {
        performClearForFullSync = true;
        originalContactsForDiff = []; // 전체 동기화이므로 비교 대상 원본 없음
      }
    } else {
      originalContactsForDiff = []; // 강제 전체 동기화 시 비교 대상 원본 없음
    }

    final int? timestampToSend =
        performClearForFullSync ? 0 : lastSyncTimestamp;

    List<PhoneBookModel> newContactListFromStream = [];

    await _contactsStreamSubscription?.cancel();
    _contactsStreamSubscription = null;

    try {
      _contactsStreamSubscription = NativeMethods.getContactsStream(
        lastSyncTimestampEpochMillis: timestampToSend,
      ).listen(
        (List<Map<String, dynamic>> chunkData) {
          final List<PhoneBookModel> parsedChunk = _parseNativeContacts(
            chunkData,
          );
          if (parsedChunk.isNotEmpty) {
            newContactListFromStream.addAll(parsedChunk);
            log(
              '[ContactsController.syncContacts] Stream: Received chunk ${parsedChunk.length}. Total for this stream: ${newContactListFromStream.length}',
            );
          }
        },
        onError: (error, stackTrace) {
          log(
            '[ContactsController.syncContacts] Error in stream: $error',
            stackTrace: stackTrace,
          );
          _finishSyncInternal(isSuccess: false);
        },
        onDone: () async {
          log(
            '[ContactsController.syncContacts] Stream done. Total from stream: ${newContactListFromStream.length}.',
          );
          await _handleSyncCompletionInternal(
            newContactListFromStream,
            originalContactsForDiff,
            performClearForFullSync,
          );
        },
      );
      if (!_initialLoadAttempted) {
        _initialLoadAttempted = true; // 스트림 구독 시작 = 로드 시도
      }
    } catch (e, s) {
      log(
        '[ContactsController.syncContacts] Error starting stream: $e',
        stackTrace: s,
      );
      _finishSyncInternal(isSuccess: false);
    }
  }

  Future<void> _handleSyncCompletionInternal(
    List<PhoneBookModel>
    newOrUpdatedContactsFromStream, // 스트림에서 받은 데이터 (전체 또는 델타)
    List<PhoneBookModel> originalContactsAtSyncStart, // 동기화 시작 시점의 _contacts 상태
    bool wasFullRefresh, // 이 동기화가 전체 새로고침이었는지 여부
  ) async {
    List<PhoneBookModel> finalContactsToSave;

    if (wasFullRefresh) {
      finalContactsToSave = List.from(newOrUpdatedContactsFromStream);
    } else {
      // 델타 업데이트: newOrUpdatedContactsFromStream은 변경/추가된 것들임
      // 이미 onData에서 _contacts에 실시간으로 반영하려고 시도했으나, 최종적으로 여기서 한번 더 정리.
      Map<String, PhoneBookModel> combinedContactsMap = {
        for (var c in originalContactsAtSyncStart) c.contactId: c,
      }; // 현재 _contacts를 기반으로 Map 생성
      for (var updatedContact in newOrUpdatedContactsFromStream) {
        combinedContactsMap[updatedContact.contactId] = updatedContact;
      }
      finalContactsToSave = combinedContactsMap.values.toList();
      log(
        '[ContactsController._handleSyncCompletionInternal] Delta refresh. Merged. Total finalContacts: ${finalContactsToSave.length}',
      );
    }
    finalContactsToSave.sort(
      (a, b) => (a.name.toLowerCase()).compareTo(b.name.toLowerCase()),
    );
    _contacts = List.from(finalContactsToSave);
    _updateContactCache();

    log(
      '[ContactsController._handleSyncCompletionInternal] Saving ${finalContactsToSave.length} contacts to Hive...',
    );
    try {
      final saveStopwatch = Stopwatch()..start();
      await _contactRepository.saveContacts(finalContactsToSave);
      saveStopwatch.stop();
      log(
        '[ContactsController._handleSyncCompletionInternal] Saved contacts to Hive in ${saveStopwatch.elapsedMilliseconds}ms.',
      );

      await _settingsRepository.setLastContactsSyncTimestamp(
        DateTime.now().millisecondsSinceEpoch,
      );

      List<PhoneBookModel> contactsToUploadForServer;
      if (wasFullRefresh || originalContactsAtSyncStart.isEmpty) {
        contactsToUploadForServer = List.from(finalContactsToSave);
      } else {
        contactsToUploadForServer = _calculateDeltaForServer(
          originalContactsAtSyncStart,
          finalContactsToSave,
        );
      }

      if (contactsToUploadForServer.isNotEmpty) {
        final recordsToUpsert =
            contactsToUploadForServer.map((contact) {
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

        try {
          await PhoneRecordsApi.upsertPhoneRecords(recordsToUpsert);
        } catch (e, s) {
          log(
            '[ContactsController._handleSyncCompletionInternal] Error uploading contacts to server: $e',
            stackTrace: s,
          );
        }
      } else {
        log(
          '[ContactsController._handleSyncCompletionInternal] No changes to upload to server.',
        );
      }
    } catch (e, s) {
      log(
        '[ContactsController._handleSyncCompletionInternal] Error during Hive save or server upload: $e',
        stackTrace: s,
      );
    } finally {
      _finishSyncInternal(isSuccess: true);
    }
  }

  List<PhoneBookModel> _calculateDeltaForServer(
    List<PhoneBookModel> original,
    List<PhoneBookModel> current,
  ) {
    final List<PhoneBookModel> delta = [];
    final Map<String, PhoneBookModel> originalMap = {
      for (var c in original) c.contactId: c,
    };

    // 추가되거나 수정된 항목 찾기
    for (var contactInCurrent in current) {
      final originalContact = originalMap[contactInCurrent.contactId];
      if (originalContact == null) {
        // 새로 추가된 연락처
        delta.add(contactInCurrent);
      } else {
        // 기존 연락처 -> 내용 비교하여 변경된 경우만 업로드
        bool nameChanged = originalContact.name != contactInCurrent.name;
        bool phoneChanged =
            normalizePhone(originalContact.phoneNumber) !=
            normalizePhone(contactInCurrent.phoneNumber);
        bool timestampChanged =
            (originalContact.createdAt?.millisecondsSinceEpoch ?? 0) !=
            (contactInCurrent.createdAt?.millisecondsSinceEpoch ?? 0);
        if (nameChanged || phoneChanged || timestampChanged) {
          delta.add(contactInCurrent);
        }
      }
    }
    // 네이티브에서 삭제된 연락처를 서버에도 반영하려면, 여기서 originalMap에 있지만 currentMap에 없는 항목을 찾아
    // 서버에 삭제 요청을 보내는 로직 추가 필요 (현재는 삭제 API 없음)
    return delta;
  }

  void _finishSyncInternal({required bool isSuccess}) {
    _isSyncing = false;
    _isLoading = false;
    notifyListeners();
    log(
      '[ContactsController._finishSyncInternal] Sync finished. Success: $isSuccess',
    );
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
