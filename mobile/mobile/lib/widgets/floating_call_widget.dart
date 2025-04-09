import 'package:flutter/material.dart';
import 'package:mobile/providers/call_state_provider.dart';
import 'package:mobile/screens/home_screen.dart'; // CallState enum 사용 위해 임시 임포트 (나중에 분리)
import 'package:mobile/widgets/dialer_content.dart'; // <<< 새 위젯 임포트
import 'dart:developer';
import 'package:mobile/widgets/incoming_call_content.dart'; // <<< 새 위젯 임포트
import 'package:mobile/widgets/on_call_contents.dart'; // <<< 새 위젯 임포트
import 'package:mobile/widgets/call_ended_content.dart'; // <<< 새 위젯 임포트
import 'package:mobile/controllers/contacts_controller.dart'; // <<< 컨트롤러 임포트
import 'package:mobile/controllers/search_records_controller.dart'; // <<< 컨트롤러 임포트
import 'package:mobile/models/search_result_model.dart'; // <<< 모델 임포트
import 'package:provider/provider.dart'; // <<< Provider 임포트
import 'package:mobile/utils/constants.dart'; // normalizePhone
import 'package:mobile/controllers/phone_state_controller.dart'; // <<< PhoneStateController 임포트
import 'dart:async';

class FloatingCallWidget extends StatefulWidget {
  final bool isVisible; // 팝업 표시 여부
  final CallState callState;
  final String number; // 초기 번호 (이름 조회 전)
  final String callerName; // 외부에서 받은 이름 (업데이트될 수 있음)
  final bool connected; // <<< 추가
  final int duration; // <<< 파라미터 추가
  final VoidCallback onClosePopup; // 팝업 닫기 콜백
  final VoidCallback onHangUp; // <<< 추가

  const FloatingCallWidget({
    super.key,
    required this.isVisible,
    required this.callState,
    required this.number,
    required this.callerName,
    required this.connected, // <<< 추가
    required this.duration, // <<< 파라미터 추가
    required this.onClosePopup,
    required this.onHangUp, // <<< 추가
  });

  @override
  State<FloatingCallWidget> createState() => _FloatingCallWidgetState();
}

class _FloatingCallWidgetState extends State<FloatingCallWidget> {
  // <<< 데이터 로딩 상태 관리 >>>
  bool _isLoading = false;
  String? _error;
  SearchResultModel? _searchResult;
  String _loadedCallerName = ''; // 로드된 이름 저장

  @override
  void initState() {
    super.initState();
    _loadedCallerName = widget.callerName;
    if (widget.isVisible && widget.callState == CallState.incoming) {
      _loadIncomingData();
    }
  }

  @override
  void didUpdateWidget(FloatingCallWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // <<< 데이터 로딩 조건 수정 >>>
    bool needsLoad = false;
    if (widget.isVisible && widget.callState == CallState.incoming) {
      // 팝업이 열렸거나 번호가 변경되었는지 확인
      bool visibilityChanged = !oldWidget.isVisible && widget.isVisible;
      bool numberChanged = oldWidget.number != widget.number;

      // 이전에 로딩된 결과가 있고 번호가 같다면 로드 안 함
      bool alreadyLoadedWithSameNumber =
          (_searchResult != null || _error != null) && !numberChanged;

      if ((visibilityChanged || numberChanged) &&
          !_isLoading &&
          !alreadyLoadedWithSameNumber) {
        needsLoad = true;
        log(
          '[FloatingCallWidget] Needs incoming data load. VisibleChanged: $visibilityChanged, NumberChanged: $numberChanged, IsLoading: $_isLoading, AlreadyLoaded: $alreadyLoadedWithSameNumber',
        );
      }
    }

    // 팝업이 닫혔거나 상태가 incoming이 아니면 로딩 중단/초기화 (선택적)
    if (!widget.isVisible || widget.callState != CallState.incoming) {
      if (_isLoading) {
        // TODO: Cancel ongoing network requests if possible
        log(
          '[FloatingCallWidget] Cancelling potential load due to state/visibility change.',
        );
        if (mounted) setState(() => _isLoading = false);
      }
      // _searchResult = null; // 필요 시 결과 초기화
      // _loadedCallerName = '';
    }

    if (needsLoad) {
      _loadIncomingData();
    }
  }

  // <<< 데이터 로딩 함수 (재진입 방지 추가) >>>
  Future<void> _loadIncomingData() async {
    if (!mounted || _isLoading) return; // <<< 재진입 방지
    setState(() {
      _isLoading = true;
      _error = null;
      _searchResult = null;
    });
    log('[FloatingCallWidget] Loading incoming data for ${widget.number}...');

    try {
      final normalizedNumber = normalizePhone(widget.number);
      // <<< PhoneStateController 통해 이름 조회 >>>
      final phoneStateCtrl = context.read<PhoneStateController>();
      _loadedCallerName = await phoneStateCtrl.getContactName(widget.number);
      if (!mounted) return;
      setState(() {});

      // 검색 데이터 로드 (SearchRecordsController 사용)
      final phoneData = await SearchRecordsController.searchPhone(
        normalizedNumber,
      );
      if (!mounted) return;
      final todayRecords = await SearchRecordsController.searchTodayRecord(
        normalizedNumber,
      );
      if (!mounted) return;

      setState(() {
        _searchResult = SearchResultModel(
          phoneNumberModel: phoneData,
          todayRecords: todayRecords,
        );
        _isLoading = false;
      });
      log('[FloatingCallWidget] Incoming data loaded successfully.');
    } catch (e, st) {
      log('[FloatingCallWidget] Error loading incoming data: $e\n$st');
      if (mounted) {
        setState(() {
          _error = '데이터 로딩 실패';
          _isLoading = false;
        });
      }
    } finally {
      // <<< finally 블록 추가하여 로딩 상태 확실히 해제 >>>
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    double panelBorderRadius = 20.0;

    // --- 확장 팝업 컨텐츠 결정 ---
    Widget popupContent;
    switch (widget.callState) {
      case CallState.idle:
        popupContent = DialerContent();
        break;
      case CallState.incoming:
        popupContent = IncomingCallContent(
          callerName: _loadedCallerName,
          number: widget.number,
          searchResult: _searchResult,
          isLoading: _isLoading,
          error: _error,
          // TODO: Add onAccept/onReject callbacks
        );
        break;
      case CallState.active:
        popupContent = OnCallContents(
          callerName:
              _loadedCallerName.isNotEmpty
                  ? _loadedCallerName
                  : widget.callerName,
          number: widget.number,
          connected: widget.connected,
          onHangUp: widget.onHangUp, // <<< 콜백 전달
          duration: widget.duration, // <<< duration 전달
        );
        break;
      case CallState.ended:
        popupContent = CallEndedContent(
          callerName:
              _loadedCallerName.isNotEmpty
                  ? _loadedCallerName
                  : widget.callerName,
          number: widget.number,
          reason: 'ended', // TODO: 실제 종료 이유(예: missed) 전달 필요
        );
        break;
      default:
        popupContent = const SizedBox.shrink();
    }

    // isVisible 상태에 따라 투명도만 조절
    return IgnorePointer(
      // 팝업이 안보일때는 탭 이벤트 무시
      ignoring: !widget.isVisible,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: widget.isVisible ? 1.0 : 0.0,
        child: Material(
          // Material 위젯으로 감싸 Elevation과 BorderRadius 적용
          elevation: 4.0,
          borderRadius: BorderRadius.all(Radius.circular(panelBorderRadius)),
          color: Theme.of(context).cardColor, // 배경색 설정
          clipBehavior: Clip.antiAlias, // 내부 컨텐츠가 borderRadius를 넘지 않도록
          child: Stack(
            children: [
              Positioned.fill(
                child: popupContent, // 패널 내용
              ),
              Positioned(
                top: 8.0,
                right: 8.0,
                child: IconButton(
                  icon: const Icon(
                    Icons.keyboard_arrow_down,
                    color: Colors.grey,
                  ),
                  onPressed: widget.onClosePopup, // 닫기 콜백
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
