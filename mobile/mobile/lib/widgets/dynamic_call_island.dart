import 'package:flutter/material.dart';
import 'package:mobile/screens/home_screen.dart'; // CallState enum 사용 위해 임시 임포트 (나중에 분리)
import 'dart:async'; // Timer 사용 위해 (통화 시간)
import 'dart:developer'; // 로그

class DynamicCallIsland extends StatefulWidget {
  final CallState callState;
  final String number;
  final String callerName;
  final bool isPopupVisible; // 팝업 표시 여부 (버튼 비활성화 등에 사용될 수 있음)
  final VoidCallback onTogglePopup; // 팝업 토글 콜백
  final bool connected; // <<< 추가

  const DynamicCallIsland({
    super.key,
    required this.callState,
    required this.number,
    required this.callerName,
    required this.isPopupVisible,
    required this.onTogglePopup,
    required this.connected, // <<< 추가
  });

  @override
  State<DynamicCallIsland> createState() => _DynamicCallIslandState();
}

class _DynamicCallIslandState extends State<DynamicCallIsland> {
  Timer? _callTimer;
  int _callDuration = 0;

  @override
  void initState() {
    super.initState();
    _updateTimerBasedOnState(
      widget.callState == CallState.active && widget.connected,
    );
  }

  @override
  void didUpdateWidget(DynamicCallIsland oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.callState != widget.callState ||
        oldWidget.connected != widget.connected) {
      log(
        '[Island] State/Connected changed: ${widget.callState} / ${widget.connected}',
      );
      _updateTimerBasedOnState(
        widget.callState == CallState.active && widget.connected,
      );
      if (widget.callState == CallState.ended) {
        // TODO: Implement 30-second timer to revert to idle state?
      }
    }
  }

  void _updateTimerBasedOnState(bool shouldRunTimer) {
    if (shouldRunTimer) {
      _startCallTimer();
    } else {
      _stopCallTimer();
    }
  }

  void _startCallTimer() {
    _stopCallTimer();
    _callDuration = 0;
    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && widget.callState == CallState.active && widget.connected) {
        setState(() {
          _callDuration++;
        });
      } else {
        timer.cancel();
      }
    });
    log('[Island] Call timer started.');
  }

  void _stopCallTimer() {
    _callTimer?.cancel();
    _callTimer = null;
    _callDuration = 0;
    log('[Island] Call timer stopped.');
  }

  @override
  void dispose() {
    _stopCallTimer();
    super.dispose();
  }

  String _formatDuration(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return "$minutes:$secs";
  }

  @override
  Widget build(BuildContext context) {
    double fabSize = 60.0;
    double barHeightIdle = 60.0;
    double barHeightActive = 70.0;
    double barPaddingHorizontal = 16.0;
    double targetBarHeight = barHeightIdle;
    double targetBarWidth = fabSize;
    BorderRadius targetBorderRadius = BorderRadius.circular(fabSize / 2);
    Color targetBarColor = Theme.of(context).colorScheme.secondary;
    Widget barContent;
    IconData leadingIcon = Icons.error;
    bool showExpandButton = false;

    // 상태에 따른 바/버튼 모양 및 내용 결정
    switch (widget.callState) {
      case CallState.idle:
        targetBarHeight = barHeightIdle;
        targetBarWidth = fabSize;
        targetBorderRadius = BorderRadius.circular(fabSize / 2);
        if (widget.isPopupVisible) {
          targetBarColor = Colors.grey.shade700;
          barContent = Icon(
            Icons.keyboard_arrow_down,
            color: Colors.white,
            size: fabSize * 0.6,
          );
        } else {
          targetBarColor = Colors.black;
          barContent = Icon(
            Icons.dialpad,
            color: Colors.white,
            size: fabSize * 0.6,
          );
        }
        showExpandButton = true;
        break;
      case CallState.incoming:
        targetBarHeight = barHeightActive;
        targetBarWidth =
            MediaQuery.of(context).size.width - (barPaddingHorizontal * 2);
        targetBorderRadius = BorderRadius.circular(targetBarHeight / 2);
        targetBarColor = Colors.green;
        leadingIcon = Icons.call;
        barContent = _buildBarContent(
          leadingIcon,
          "전화 수신 중",
          widget.callerName,
          widget.number,
        );
        break;
      case CallState.active:
        targetBarHeight = barHeightActive;
        targetBarWidth =
            MediaQuery.of(context).size.width - (barPaddingHorizontal * 2);
        targetBorderRadius = BorderRadius.circular(targetBarHeight / 2);
        targetBarColor = Colors.black;
        leadingIcon = Icons.phone_in_talk;
        barContent = _buildBarContent(
          leadingIcon,
          widget.connected
              ? "통화 중 (${_formatDuration(_callDuration)})"
              : "연결 중...",
          widget.callerName,
          widget.number,
        );
        break;
      case CallState.ended:
        targetBarHeight = barHeightActive;
        targetBarWidth =
            MediaQuery.of(context).size.width - (barPaddingHorizontal * 2);
        targetBorderRadius = BorderRadius.circular(targetBarHeight / 2);
        targetBarColor = Colors.grey;
        leadingIcon = Icons.check_circle_outline;
        barContent = _buildBarContent(
          leadingIcon,
          "통화 종료",
          widget.callerName,
          widget.number,
        );
        // TODO: Add timer logic here to revert to idle after 30 seconds
        break;
    }

    // AnimatedContainer가 버튼/바 역할
    return GestureDetector(
      onTap: widget.onTogglePopup, // 모든 상태에서 탭하면 팝업 토글 콜백 호출
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        width: targetBarWidth,
        height: targetBarHeight,
        decoration: BoxDecoration(
          color: targetBarColor,
          borderRadius: targetBorderRadius,
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 8.0,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            // 탭 효과
            borderRadius: targetBorderRadius,
            onTap: widget.onTogglePopup, // InkWell에도 onTap 설정
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: targetBarWidth == fabSize ? 0 : 12.0,
              ),
              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder: (child, animation) {
                    return FadeTransition(opacity: animation, child: child);
                  },
                  child: barContent,
                  key: ValueKey(
                    widget.callState.toString() +
                        widget.isPopupVisible.toString(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 바 내용 생성 헬퍼 (Row 반환)
  Widget _buildBarContent(
    IconData leadingIcon,
    String status,
    String name,
    String number,
  ) {
    String displayName = name.isNotEmpty ? name : "알 수 없음";
    Color iconColor = Colors.white;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center, // Row 내용 가운데 정렬
      children: [
        Icon(leadingIcon, color: iconColor, size: 30),
        SizedBox(width: 8),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                status,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 1),
              Text(
                "$displayName $number",
                style: TextStyle(color: Colors.white, fontSize: 13),
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        // <<< 확장 버튼(화살표) 제거 >>>
      ],
    );
  }
}
