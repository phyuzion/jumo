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

    // 메모 필드 가져오기
    String memo = (c['memo'] ?? '').toString().trim();

    result.add(
      PhoneBookModel(
        contactId: c['id']?.toString() ?? '',
        rawContactId: c['rawId']?.toString(),
        name: displayName, // 최종 결정된 displayName 사용
        // 개별 이름 필드도 모델에 저장하려면 PhoneBookModel에 필드 추가 필요
        // firstName: firstName,
        // lastName: lastName,
        phoneNumber: normPhone,
        memo: memo, // 메모 필드 추가
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
      Map<String, PhoneBookModel> combinedContactsMap = {
        for (var c in originalContactsAtSyncStart) c.contactId: c,
      };
      // 전화번호를 키로 하는 맵도 준비 (기존 연락처 업데이트용)
      Map<String, PhoneBookModel> phoneToOriginalContactMap = {
        for (var c in originalContactsAtSyncStart)
          normalizePhone(c.phoneNumber): c,
      };

      List<PhoneBookModel> contactsFromStream = List.from(
        newOrUpdatedContactsFromStream,
      );

      for (var streamedContact in contactsFromStream) {
        final normalizedStreamedPhone = normalizePhone(
          streamedContact.phoneNumber,
        );
        PhoneBookModel? existingContactById =
            combinedContactsMap[streamedContact.contactId];
        PhoneBookModel? existingContactByPhone =
            phoneToOriginalContactMap[normalizedStreamedPhone];

        if (existingContactById != null) {
          // ID가 일치하는 경우: 가장 확실한 업데이트 대상

          combinedContactsMap[streamedContact.contactId] = streamedContact;
          // 만약 이전에 전화번호로 매칭되었던 다른 ID의 연락처가 있고, 그 ID가 현재 업데이트하는 ID와 다르다면,
          // 그 이전 전화번호 매칭 항목을 combinedContactsMap에서 제거 (ID 기반 업데이트 우선)
          if (existingContactByPhone != null &&
              existingContactByPhone.contactId != streamedContact.contactId) {
            combinedContactsMap.remove(existingContactByPhone.contactId);
          }
          phoneToOriginalContactMap[normalizedStreamedPhone] =
              streamedContact; // 전화번호 맵도 최신 정보로 업데이트
        } else if (existingContactByPhone != null) {
          // ID는 다르지만 전화번호가 일치하는 경우: "수정"으로 간주하고 기존 항목을 새 ID의 항목으로 대체

          combinedContactsMap.remove(
            existingContactByPhone.contactId,
          ); // 이전 ID 항목 제거
          combinedContactsMap[streamedContact.contactId] =
              streamedContact; // 새 ID 항목 추가/업데이트
          phoneToOriginalContactMap[normalizedStreamedPhone] =
              streamedContact; // 전화번호 맵 업데이트
        } else {
          // ID도 전화번호도 일치하는 기존 항목 없음: 새 연락처로 추가

          combinedContactsMap[streamedContact.contactId] = streamedContact;
          phoneToOriginalContactMap[normalizedStreamedPhone] = streamedContact;
        }
      }
      finalContactsToSave = combinedContactsMap.values.toList();
    }
    finalContactsToSave.sort(
      (a, b) => (a.name.toLowerCase()).compareTo(b.name.toLowerCase()),
    );
    _contacts = List.from(finalContactsToSave);
    // _contacts 할당 직후 상태 로깅 추가

    _updateContactCache();

    try {
      final saveStopwatch = Stopwatch()..start();
      await _contactRepository.saveContacts(finalContactsToSave);
      saveStopwatch.stop();

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
              // 메모 필드 추가 (서버 API가 이제 지원함)
              if (contact.memo != null && contact.memo!.isNotEmpty) {
                serverMap['memo'] = contact.memo;
              }
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
        bool memoChanged = originalContact.memo != contactInCurrent.memo; // 메모 변경 감지
        bool timestampChanged =
            (originalContact.createdAt?.millisecondsSinceEpoch ?? 0) !=
            (contactInCurrent.createdAt?.millisecondsSinceEpoch ?? 0);
        if (nameChanged || phoneChanged || memoChanged || timestampChanged) {
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
