// lib/services/search_service.dart (또는 controllers/search_controller.dart)

import 'dart:async';
import 'dart:developer';
import 'package:flutter/foundation.dart';
import 'package:mobile/graphql/search_api.dart';
// import 'package:mobile/graphql/today_record_api.dart';
import 'package:mobile/models/phone_number_model.dart';
import 'package:mobile/utils/constants.dart';
import 'package:mobile/models/today_record.dart';
import 'package:mobile/utils/app_event_bus.dart';

class SearchRecordsController extends ChangeNotifier {
  // 검색 결과 및 상태 관리
  PhoneNumberModel? _searchResult;
  String _phoneNumber = '';
  String _callerName = '';
  bool _searchInProgress = false;

  // 중복 검색 방지를 위한 변수
  DateTime _lastSearchTime = DateTime.now();
  int _searchDuplicateThrottleMs = 2000; // 2초 내 동일 번호 검색 방지

  // 이벤트 리스너
  StreamSubscription? _resetEventSubscription;

  PhoneNumberModel? get currentSearchResult => _searchResult;
  String get currentPhoneNumber => _phoneNumber;
  String get currentCallerName => _callerName;
  bool get isSearching => _searchInProgress;

  SearchRecordsController() {
    // 이벤트 구독 설정
    _resetEventSubscription = appEventBus.on<CallSearchResetEvent>().listen(
      _handleResetEvent,
    );
    log('[SearchRecordsController] 생성됨. 이벤트 리스너 설정 완료.');
  }

  void _handleResetEvent(CallSearchResetEvent event) {
    log(
      '[SearchRecordsController][CRITICAL] 검색 데이터 리셋 이벤트 수신: ${event.phoneNumber}',
    );
    resetSearchData();
  }

  // 명시적인 데이터 리셋 메서드
  void resetSearchData() {
    log('[SearchRecordsController][CRITICAL] 검색 데이터 명시적 초기화');

    // 검색 결과 초기화
    _searchResult = null;
    _phoneNumber = '';
    _callerName = '';
    _searchInProgress = false;

    // 리스너에게 초기화 알림 - 마이크로태스크로 지연
    Future.microtask(() => notifyListeners());
    log('[SearchRecordsController] 검색 데이터 초기화 완료 및 리스너 알림');
  }

  /// 전화번호 검색 수행 → PhoneNumberModel 리턴
  Future<PhoneNumberModel?> searchPhone(
    String rawPhone, {
    bool isRequested = false,
  }) async {
    if (rawPhone.isEmpty) {
      log('[SearchRecordsController] 빈 전화번호로 검색 시도. 무시됨.');
      return null;
    }

    final String normalizedPhone = normalizePhone(rawPhone);
    log('[SearchRecordsController] 전화번호 검색 시작: $normalizedPhone');

    // 중복 검색 방지: 2초 내에 같은 번호로 검색 시도하면 캐시된 결과 반환
    final now = DateTime.now();
    final timeSinceLastSearch = now.difference(_lastSearchTime).inMilliseconds;
    if (normalizedPhone == _phoneNumber && 
        timeSinceLastSearch < _searchDuplicateThrottleMs &&
        _searchResult != null) {
      log('[SearchRecordsController] 최근 동일 번호 검색 중복 감지 ($timeSinceLastSearch ms). 캐시된 결과 반환: $_callerName');
      return _searchResult;
    }

    _lastSearchTime = now;

    // 검색 상태 업데이트
    _searchInProgress = true;
    _phoneNumber = normalizedPhone;
    // 빌드 사이클에서 충돌 방지를 위해 마이크로태스크로 지연
    Future.microtask(() => notifyListeners());

    try {
      // 항상 서버에서 최신 데이터 요청
      final data = await SearchApi.getPhoneNumber(
        normalizedPhone,
        isRequested: isRequested,
      );

      // 결과 처리
      _searchResult = data;
      _callerName = _getCallerName(data);

      log('[SearchRecordsController] 검색 완료: $_callerName');
    } catch (e) {
      log('[SearchRecordsController] 검색 중 오류 발생: $e');
      _searchResult = null;
    } finally {
      _searchInProgress = false;
      // 빌드 사이클에서 충돌 방지를 위해 마이크로태스크로 지연
      Future.microtask(() => notifyListeners());
    }

    return _searchResult;
  }

  // 호출자 이름을 얻는 헬퍼 메서드
  String _getCallerName(PhoneNumberModel? model) {
    if (model == null) return '';

    // 레코드가 있는 경우 첫 번째 레코드의 이름 사용
    if (model.records.isNotEmpty) {
      return model.records.first.name;
    }

    // 오늘의 레코드가 있는 경우 사용
    if (model.todayRecords.isNotEmpty &&
        model.todayRecords.first.userName.isNotEmpty) {
      return model.todayRecords.first.userName;
    }

    // 이름 정보가 없는 경우 전화번호 반환
    return model.phoneNumber;
  }

  @override
  void dispose() {
    _resetEventSubscription?.cancel();
    super.dispose();
    log('[SearchRecordsController] 소멸됨. 이벤트 리스너 정리 완료.');
  }

  // static Future<List<TodayRecord>> searchTodayRecord(String phoneNumber) async {
  //   final norm = normalizePhone(phoneNumber);
  //   // 실제 서버 호출
  //   final records = await TodayRecordApi.getTodayRecord(norm);
  //   return records;
  // }
}
