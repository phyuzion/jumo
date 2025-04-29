import 'package:flutter/material.dart';
import 'package:mobile/providers/call_state_provider.dart';
// import 'package:mobile/screens/home_screen.dart'; // <<< 임시 임포트 제거
import 'package:mobile/widgets/dialer_content.dart'; // <<< 새 위젯 임포트
import 'dart:developer';
import 'package:mobile/widgets/incoming_call_content.dart'; // <<< 새 위젯 임포트
import 'package:mobile/widgets/on_call_contents.dart'; // <<< 새 위젯 임포트
import 'package:mobile/widgets/call_ended_content.dart'; // <<< 새 위젯 임포트
import 'package:mobile/controllers/search_records_controller.dart'; // <<< 컨트롤러 임포트
import 'package:mobile/models/search_result_model.dart'; // <<< 모델 임포트
import 'package:provider/provider.dart'; // <<< Provider 임포트
import 'package:mobile/utils/constants.dart'; // normalizePhone
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

  @override
  void initState() {
    super.initState();
    if (widget.isVisible && widget.callState == CallState.incoming) {
      _loadSearchResult();
    }
  }

  @override
  void didUpdateWidget(FloatingCallWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // <<< 데이터 로딩 조건 수정 (searchResult 로딩만 고려) >>>
    bool needsLoad = false;
    if (widget.isVisible && widget.callState == CallState.incoming) {
      bool visibilityChanged = !oldWidget.isVisible && widget.isVisible;
      bool numberChanged = oldWidget.number != widget.number;
      bool alreadyLoadedWithSameNumber =
          (_searchResult != null || _error != null) && !numberChanged;

      if ((visibilityChanged || numberChanged) &&
          !_isLoading &&
          !alreadyLoadedWithSameNumber) {
        needsLoad = true;
      }
    }

    if (!widget.isVisible || widget.callState != CallState.incoming) {
      if (_isLoading) {
        if (mounted) setState(() => _isLoading = false);
      }
    }

    if (needsLoad) {
      _loadSearchResult();
    }
  }

  Future<void> _loadSearchResult() async {
    if (!mounted || _isLoading) return;
    setState(() {
      _isLoading = true;
      _error = null;
      _searchResult = null;
    });

    try {
      final normalizedNumber = normalizePhone(widget.number);

      final phoneData = await SearchRecordsController.searchPhone(
        normalizedNumber,
      );
      if (!mounted) return;
      setState(() {
        _searchResult = SearchResultModel(
          phoneNumberModel: phoneData,
          todayRecords: phoneData?.todayRecords ?? [],
        );
        _isLoading = false;
      });
    } catch (e, st) {
      log('[FloatingCallWidget] Error loading search data: $e\n$st');
      if (mounted) {
        setState(() {
          _error = '데이터 로딩 실패';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    double panelBorderRadius = 20.0;

    final callStateProvider = context.watch<CallStateProvider>();
    // <<< currentCallerName이 비어있으면 widget.number 사용 >>>
    final currentCallerName = callStateProvider.callerName;
    final displayName =
        currentCallerName.isNotEmpty ? currentCallerName : widget.number;

    // --- 확장 팝업 컨텐츠 결정 ---
    Widget popupContent;
    switch (widget.callState) {
      case CallState.idle:
        popupContent = DialerContent();
        break;
      case CallState.incoming:
        popupContent = IncomingCallContent(
          callerName: displayName, // <<< 수정된 displayName 전달
          number: widget.number,
          searchResult: _searchResult,
          isLoading: _isLoading,
          error: _error,
        );
        break;
      case CallState.active:
        popupContent = OnCallContents(
          callerName: displayName, // <<< 수정된 displayName 전달
          number: widget.number,
          connected: widget.connected,
          onHangUp: widget.onHangUp,
          duration: widget.duration,
        );
        break;
      case CallState.ended:
        popupContent = CallEndedContent(
          callerName: displayName, // <<< 수정된 displayName 전달
          number: widget.number,
          reason: callStateProvider.callEndReason,
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
