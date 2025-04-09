import 'package:flutter/material.dart';
import 'package:mobile/screens/home_screen.dart'; // CallState enum 사용 위해 임시 임포트 (나중에 분리)
import 'package:mobile/screens/dialer_screen.dart';
import 'dart:developer';
import 'package:mobile/widgets/incoming_call_content.dart'; // <<< 새 위젯 임포트
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
  final int duration; // 통화 시간 등 필요 데이터
  final VoidCallback onClosePopup; // 팝업 닫기 콜백

  const FloatingCallWidget({
    super.key,
    required this.isVisible,
    required this.callState,
    required this.number,
    required this.callerName,
    required this.duration,
    required this.onClosePopup,
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

  // <<< 타이머 관련 변수 추가 >>>
  Timer? _callTimer;
  int _internalDuration = 0;

  @override
  void initState() {
    super.initState();
    _loadedCallerName = widget.callerName;
    // <<< initState에서도 타이머 상태 업데이트 호출 >>>
    _updateTimerBasedOnState(widget.callState);
    if (widget.isVisible && widget.callState == CallState.incoming) {
      _loadIncomingData();
    }
  }

  @override
  void didUpdateWidget(FloatingCallWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.callState != widget.callState) {
      _updateTimerBasedOnState(widget.callState);
    }

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

  // <<< 타이머 상태 업데이트 함수 추가 >>>
  void _updateTimerBasedOnState(CallState state) {
    if (state == CallState.active) {
      _startCallTimer();
    } else {
      _stopCallTimer();
    }
  }

  // <<< 타이머 시작 함수 추가 >>>
  void _startCallTimer() {
    _stopCallTimer();
    _internalDuration = 0;
    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && widget.callState == CallState.active) {
        setState(() {
          _internalDuration++;
        });
      } else {
        timer.cancel();
      }
    });
    log('[FloatingCallWidget] Call timer started.');
  }

  // <<< 타이머 중지 함수 추가 >>>
  void _stopCallTimer() {
    _callTimer?.cancel();
    _callTimer = null;
    _internalDuration = 0;
    log('[FloatingCallWidget] Call timer stopped.');
  }

  // <<< dispose에 타이머 중지 추가 >>>
  @override
  void dispose() {
    _stopCallTimer();
    super.dispose();
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
        popupContent = DialerScreen();
        break;
      case CallState.incoming:
        // <<< IncomingCallContent에 로딩 상태와 데이터 전달 >>>
        popupContent = IncomingCallContent(
          callerName: _loadedCallerName, // 로드된 이름 사용
          number: widget.number,
          searchResult: _searchResult,
          isLoading: _isLoading,
          error: _error,
          // TODO: Add onAccept/onReject callbacks if needed
        );
        break;
      case CallState.active:
        popupContent = Center(
          child: Text(
            "On Call UI Placeholder: ${_loadedCallerName.isNotEmpty ? _loadedCallerName : widget.callerName} (${widget.number}) - $_internalDuration s",
          ),
        );
        break;
      case CallState.ended:
        popupContent = Center(
          child: Text(
            "Ended UI Placeholder: ${_loadedCallerName.isNotEmpty ? _loadedCallerName : widget.callerName} (${widget.number})",
          ),
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
