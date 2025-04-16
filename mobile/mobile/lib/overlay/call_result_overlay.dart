// lib/overlays/call_result_overlay.dart

import 'dart:async';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:mobile/models/search_result_model.dart';
import 'package:mobile/widgets/search_result_widget.dart';
import 'package:system_alert_window/system_alert_window.dart';
import 'package:hive_ce/hive.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:mobile/models/blocked_history.dart';

class CallResultOverlay extends StatefulWidget {
  const CallResultOverlay({Key? key}) : super(key: key);

  @override
  State<CallResultOverlay> createState() => _CallResultOverlayState();
}

class _CallResultOverlayState extends State<CallResultOverlay> {
  SearchResultModel? _result;
  String? _phoneNumber;
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = true; // 초기 상태는 로딩 중
  bool _isOverlayVisible = false; // 오버레이 표시 여부 상태

  StreamSubscription? _overlayListenerSubscription; // 리스너 구독 관리

  // <<< Hive 초기화 Future 저장 변수 >>>
  Future<void>? _hiveInitFuture;

  @override
  void initState() {
    super.initState();
    // <<< Hive 초기화 Future 저장 >>>
    _hiveInitFuture = _initializeHive();
    _listenToOverlayEvents();
  }

  // <<< 오버레이 Isolate 위한 Hive 초기화 (Future 반환) >>>
  Future<void> _initializeHive() async {
    final appDocumentDir = await getApplicationDocumentsDirectory();
    await Hive.initFlutter(appDocumentDir.path);

    // TypeAdapter 등록
    if (!Hive.isAdapterRegistered(BlockedHistoryAdapter().typeId)) {
      Hive.registerAdapter(BlockedHistoryAdapter());
      log('BlockedHistoryAdapter registered.');
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _overlayListenerSubscription?.cancel(); // 리스너 해제
    super.dispose();
  }

  void _listenToOverlayEvents() {
    // 기존 리스너가 있다면 취소
    _overlayListenerSubscription?.cancel();

    // 새 리스너 등록
    _overlayListenerSubscription = SystemAlertWindow.overlayListener.listen((
      data,
    ) {
      if (data is! Map<String, dynamic>) {
        log(
          '[CallResultOverlay] Received invalid data type: ${data.runtimeType}',
        );
        return;
      }

      final type = data['type'] as String?;
      final phoneNumber = data['phoneNumber'] as String?;

      log('[CallResultOverlay] Received data: type=$type, number=$phoneNumber');

      if (type == 'ringing') {
        setState(() {
          _phoneNumber = phoneNumber;
          _isLoading = true;
          _result = null; // 이전 결과 초기화
        });
        _showOverlayIfNeeded(); // 오버레이 표시 시도
      } else if (type == 'result') {
        final searchResultData = data['searchResult'] as Map<String, dynamic>?;
        setState(() {
          _phoneNumber = phoneNumber; // 번호는 결과에도 포함되므로 업데이트
          _isLoading = false;
          if (searchResultData != null) {
            try {
              _result = SearchResultModel.fromJson(searchResultData);
              log('[CallResultOverlay] Parsed search result for $phoneNumber');
            } catch (e) {
              log(
                '[CallResultOverlay] Error parsing search result for $phoneNumber: $e',
              );
              _result = null; // 파싱 에러 시 결과 없음 처리
            }
          } else {
            _result = null; // searchResult가 null이면 결과 없음
            log(
              '[CallResultOverlay] No search result found for $phoneNumber (신규 번호)',
            );
          }
        });
        // 'result' 타입 수신 시에는 이미 오버레이가 떠 있어야 하므로 _showOverlayIfNeeded 불필요
        if (!_isOverlayVisible) {
          // 혹시 ringing을 놓치고 result만 받은 예외 케이스 대비
          log(
            '[CallResultOverlay] Warning: Received result but overlay was not visible. Showing now.',
          );
          _showOverlayIfNeeded();
        }
      } else {
        log('[CallResultOverlay] Received unknown data type: $type');
      }
    });
    log('[CallResultOverlay] Overlay listener started.');
  }

  // 오버레이를 표시해야 할 때만 호출 (중복 호출 방지)
  Future<void> _showOverlayIfNeeded() async {
    // if (_isOverlayVisible) return; // 필요 시 주석 해제
    if (_phoneNumber == null) return;

    log(
      '[CallResultOverlay] Attempting to show/update overlay for $_phoneNumber using SystemAlertWindow...',
    );
    try {
      // <<< Hive 초기화 완료 기다리기 >>>
      await _hiveInitFuture;
      log('[CallResultOverlay] Hive initialization confirmed complete.');

      // <<< Hive에서 화면 크기 읽어오기 >>>
      int screenWidth = 350;
      int screenHeight = 500;
      try {
        final settingsBox = await Hive.openBox('settings');
        final double? storedWidth = settingsBox.get('screenWidth') as double?;
        final double? storedHeight = settingsBox.get('screenHeight') as double?;
        if (storedWidth != null && storedHeight != null) {
          screenWidth = storedWidth.floor();
          screenHeight = storedHeight.floor();
          log(
            '[CallResultOverlay] Loaded screen size from Hive: W=$screenWidth, H=$screenHeight',
          );
        } else {
          log(
            '[CallResultOverlay] No screen size found in Hive. Using defaults.',
          );
        }
      } catch (e) {
        log(
          '[CallResultOverlay] Error reading screen size from Hive: $e. Using defaults.',
        );
      }

      // <<< SystemAlertWindow API 사용 및 읽어온 크기 적용 >>>
      await SystemAlertWindow.showSystemWindow(
        height: screenHeight,
        width: screenWidth,
        gravity: SystemWindowGravity.BOTTOM,
        prefMode: SystemWindowPrefMode.OVERLAY,
        notificationTitle: _phoneNumber!, // null 아님 보장됨
        notificationBody: _isLoading ? '정보 검색 중...' : '결과 확인', // 상태 반영
      );
      log('[CallResultOverlay] showSystemWindow called successfully.');
      if (!_isOverlayVisible) {
        setState(() {
          _isOverlayVisible = true;
        });
      }
    } catch (e) {
      log('[CallResultOverlay] Error showing/updating overlay: $e');
      if (mounted && _isOverlayVisible) {
        setState(() {
          _isOverlayVisible = false;
        });
      }
    }
  }

  // 닫기 버튼 등에서 오버레이를 닫을 때 상태 업데이트
  Future<void> _closeOverlay() async {
    // _isOverlayVisible 상태를 먼저 false로 바꿔서 UI가 즉시 닫힌 것처럼 보이게 함 (선택적)
    // setState(() { _isOverlayVisible = false; });

    try {
      await SystemAlertWindow.closeSystemWindow();
      setState(() {
        // <<< setState 추가
        _isOverlayVisible = false; // 오버레이 닫힘 상태 업데이트
      });
      log('[CallResultOverlay] Overlay closed by user.');
    } catch (e) {
      log('[CallResultOverlay] Error closing overlay: $e');
      // 에러가 나도 상태는 false로 간주
      setState(() {
        // <<< setState 추가
        _isOverlayVisible = false;
      });
    }
  }

  void _scrollUp() {
    // Clamp 추가 및 예외 처리 보강
    if (_scrollController.hasClients) {
      final newOffset = _scrollController.offset - 100;
      _scrollController.animateTo(
        newOffset.clamp(
          0.0,
          _scrollController.position.maxScrollExtent,
        ), // double로 변경
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _scrollDown() {
    // Clamp 추가 및 예외 처리 보강
    if (_scrollController.hasClients) {
      final newOffset = _scrollController.offset + 100;
      _scrollController.animateTo(
        newOffset.clamp(
          0.0,
          _scrollController.position.maxScrollExtent,
        ), // double로 변경
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // 오버레이가 보이지 않아야 하면 빈 컨테이너 반환 (닫기 애니메이션 등 개선 여지 있음)
    if (!_isOverlayVisible) {
      return const SizedBox.shrink();
    }

    // 가로/세로에 따라 높이 지정 (기존 코드와 동일)
    final size = MediaQuery.of(context).size;

    // 데이터 길이에 따른 높이 계산 (기존 코드와 동일, _result null 체크 추가)
    final todayRecordsCount = _result?.todayRecords?.length ?? 0;
    final phoneRecordsCount = _result?.phoneNumberModel?.records?.length ?? 0;
    double baseHeight = 0.1; // 기본 높이 (예: 화면의 10%)

    // 최소/최대 높이 설정 (예시: 최소 20%, 최대 60%)
    double minHeightFactor = 0.2;
    double maxHeightFactor = 0.6;

    // 로딩 중일 때 고정 높이 또는 최소 높이 사용
    if (_isLoading) {
      baseHeight = minHeightFactor;
    } else {
      // 컨텐츠 기반 높이 계산 (SearchResultWidget 내부 구조에 따라 조정 필요)
      double contentHeightFactor = 0.0;
      // 예시: 헤더 + 여백 + 오늘 기록 + 전화번호 기록
      contentHeightFactor += 0.1; // 헤더/번호 표시 영역
      if (todayRecordsCount > 0) {
        contentHeightFactor +=
            0.05 + (todayRecordsCount * 0.05); // 섹션 헤더 + 아이템 높이 (예시)
      }
      if (phoneRecordsCount > 0) {
        contentHeightFactor +=
            0.05 + (phoneRecordsCount * 0.05); // 섹션 헤더 + 아이템 높이 (예시)
      }
      // 검색 결과 없을 때의 높이
      if (!_isLoading && _result == null) {
        contentHeightFactor = 0.15; // 예시: 번호 + "신규 번호" 텍스트 높이
      }

      baseHeight = contentHeightFactor.clamp(minHeightFactor, maxHeightFactor);
    }

    return Material(
      color: Colors.transparent,
      child: Center(
        child: Container(
          width: size.width,
          // height: size.height * baseHeight, // 동적 높이 적용
          constraints: BoxConstraints(
            // 최대/최소 높이 제약 추가
            minHeight: size.height * minHeightFactor,
            maxHeight: size.height * maxHeightFactor,
          ),
          margin: const EdgeInsets.symmetric(horizontal: 20), // 여백 유지
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15), // 약간 둥글게
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 15,
                spreadRadius: 2,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: Stack(
              children: [
                // 컨텐츠 영역
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.only(
                      bottom: 50,
                      top: 0,
                    ), // 상단 닫기, 하단 스크롤 버튼 공간
                    child: _buildContent(), // 컨텐츠 빌드 함수 사용
                  ),
                ),
                // 닫기 버튼 (항상 표시)
                Positioned(
                  top: 5, // 위치 조정
                  right: 5, // 위치 조정
                  child: IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: Colors.black54,
                    ), // 색상 조정
                    onPressed: _closeOverlay, // 닫기 함수 연결
                  ),
                ),
                // 스크롤 버튼들 (결과가 있고, 스크롤 가능할 때만?)
                if (!_isLoading && _result != null)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 50,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white.withOpacity(0.0),
                            Colors.white.withOpacity(0.9),
                            Colors.white, // 하단 확실히 가리기
                          ],
                          stops: const [0.0, 0.5, 1.0], // 그라데이션 정지점 조정
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_upward),
                            onPressed: _scrollUp,
                            color: Theme.of(context).primaryColor, // 테마 색상 사용
                          ),
                          IconButton(
                            icon: const Icon(Icons.arrow_downward),
                            onPressed: _scrollDown,
                            color: Theme.of(context).primaryColor, // 테마 색상 사용
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 컨텐츠 표시 로직 분리 (기존과 유사하게 유지, UI 개선)
  Widget _buildContent() {
    if (_isLoading) {
      // 로딩 중 표시 (UI 개선)
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min, // 컨텐츠 크기만큼만 차지
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 20),
              Text(
                _phoneNumber ?? '번호 확인 중...',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              const Text(
                '정보 검색 중...',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    } else if (_result != null) {
      // 검색 결과 있음 (SearchResultWidget 사용)
      return SearchResultWidget(
        searchResult: _result!,
        scrollController: _scrollController,
        ignorePointer: true,
      );
    } else {
      // 검색 결과 없음 (신규 번호 UI 개선)
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min, // 컨텐츠 크기만큼만 차지
            children: [
              Text(
                _phoneNumber ?? '알 수 없는 번호',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              const Text(
                '신규 번호 또는 등록된 정보 없음',
                style: TextStyle(fontSize: 16, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              // 필요 시 추가 정보나 버튼 제공 가능
            ],
          ),
        ),
      );
    }
  }
}
