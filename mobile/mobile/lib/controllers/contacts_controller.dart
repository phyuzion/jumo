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
      // 1. 로컬 저장소에서 기존 연락처 가져오기
      final List<PhoneBookModel> localContacts =
          await _contactRepository.getAllContacts();

      final Map<String, PhoneBookModel> localMap = {
        for (var c in localContacts) c.contactId: c,
      };

      // 2. 네이티브에서 최신 연락처 가져오기
      final nativeContacts = await NativeMethods.getContacts();
      final phoneBookModels = _parseNativeContacts(nativeContacts);

      // 3. 신규 또는 변경된 연락처만 필터링
      final List<PhoneBookModel> changedContacts =
          phoneBookModels.where((contact) {
            final local = localMap[contact.contactId];
            if (local == null) {
              return true; // 신규
            }
            // 네 개 필드 중 하나라도 다르면 변경된 것
            final isChanged =
                local.name != contact.name ||
                local.phoneNumber != contact.phoneNumber ||
                local.rawContactId != contact.rawContactId ||
                local.createdAt != contact.createdAt;

            if (isChanged) {
              log(
                '[ContactsController] Changed contact detected: ${contact.name} (${contact.phoneNumber})',
              );
              log('  - Name changed: ${local.name} -> ${contact.name}');
              log(
                '  - Phone changed: ${local.phoneNumber} -> ${contact.phoneNumber}',
              );
              log(
                '  - RawId changed: ${local.rawContactId} -> ${contact.rawContactId}',
              );
              log(
                '  - CreatedAt changed: ${local.createdAt} -> ${contact.createdAt}',
              );
            }
            return isChanged;
          }).toList();
      log(
        '[ContactsController] Found ${changedContacts.length} changed contacts',
      );

      _contacts = phoneBookModels;
      _contactCache = {for (var c in _contacts) c.phoneNumber: c};
      _lastLoadTime = now;
      _isLoading = false;
      notifyListeners();

      // 4. 로컬 저장소 업데이트
      await _contactRepository.saveContacts(phoneBookModels);

      // 5. 변경된 연락처만 서버에 업로드
      if (changedContacts.isNotEmpty) {
        Future(() async {
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
          } catch (e, stackTrace) {
            log('[ContactsController] Error uploading changed contacts: $e');
            log('[ContactsController] Stack trace: $stackTrace');
          }
        });
      } else {
        log('[ContactsController] No contacts to upload to server');
      }

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
