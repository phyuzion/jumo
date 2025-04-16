import 'package:flutter/material.dart';
import 'package:mobile/providers/call_state_provider.dart';
import 'dart:developer'; // 로그

class DynamicCallIsland extends StatefulWidget {
  final CallState callState;
  final String number;
  final String callerName;
  final bool isPopupVisible; // 팝업 표시 여부 (버튼 비활성화 등에 사용될 수 있음)
  final VoidCallback onTogglePopup; // 팝업 토글 콜백
  final bool connected; // <<< 추가
  final int endedCountdownSeconds; // <<< 추가
  final int duration; // <<< duration 파라미터 추가

  const DynamicCallIsland({
    super.key,
    required this.callState,
    required this.number,
    required this.callerName,
    required this.isPopupVisible,
    required this.onTogglePopup,
    required this.connected, // <<< 추가
    required this.endedCountdownSeconds, // <<< 추가
    required this.duration, // <<< 생성자에 추가
  });

  @override
  State<DynamicCallIsland> createState() => _DynamicCallIslandState();
}

class _DynamicCallIslandState extends State<DynamicCallIsland> {
  @override
  void dispose() {
    super.dispose();
  }

  String _formatDuration(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return "$minutes:$secs";
  }

  @override
  Widget build(BuildContext context) {
    // <<< 전달받은 카운트다운 값 로깅 >>>
    if (widget.callState == CallState.ended) {
      log(
        '[Island] Building for ended state. Countdown: ${widget.endedCountdownSeconds}',
      );
    }

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
    bool isPopupVisible = widget.isPopupVisible; // 가독성 위해 변수 사용
    bool showExpandButton = true; // <<< 종료 카운트다운 중에는 확장 버튼 숨김

    // <<< 팝업이 보일 때는 항상 닫기 버튼 표시 >>>
    if (isPopupVisible) {
      targetBarHeight = barHeightIdle; // 원형 버튼 크기
      targetBarWidth = fabSize;
      targetBorderRadius = BorderRadius.circular(fabSize / 2);
      targetBarColor = Colors.grey.shade700; // 닫기 버튼 색상
      barContent = Icon(
        Icons.keyboard_arrow_down,
        color: Colors.white,
        size: fabSize * 0.6,
      );
    }
    // <<< 팝업이 안 보일 때만 상태별 UI 표시 >>>
    else {
      // 상태에 따른 바/버튼 모양 및 내용 결정
      switch (widget.callState) {
        case CallState.idle:
          targetBarHeight = barHeightIdle;
          targetBarWidth = fabSize;
          targetBorderRadius = BorderRadius.circular(fabSize / 2);
          targetBarColor = Colors.black;
          barContent = Icon(
            Icons.dialpad,
            color: Colors.white,
            size: fabSize * 0.6,
          );
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
            trailingWidget: IconButton(
              icon: Icon(
                Icons.keyboard_arrow_up,
                color: Colors.white,
                size: 30,
              ),
              onPressed: widget.onTogglePopup,
              padding: EdgeInsets.zero,
              constraints: BoxConstraints(),
            ),
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
                ? "통화 중 (${_formatDuration(widget.duration)})"
                : "연결 중...",
            widget.callerName,
            widget.number,
            trailingWidget: IconButton(
              icon: Icon(
                Icons.keyboard_arrow_up,
                color: Colors.white,
                size: 30,
              ),
              onPressed: widget.onTogglePopup,
              padding: EdgeInsets.zero,
              constraints: BoxConstraints(),
            ),
          );
          break;
        case CallState.ended:
          targetBarHeight = barHeightActive;
          targetBarWidth =
              MediaQuery.of(context).size.width - (barPaddingHorizontal * 2);
          targetBorderRadius = BorderRadius.circular(targetBarHeight / 2);
          targetBarColor = Colors.grey;
          Widget countdownWidget = SizedBox(
            width: 30,
            height: 30,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: 1.0,
                  color: Colors.white.withOpacity(0.3),
                  strokeWidth: 2.0,
                ),
                CircularProgressIndicator(
                  value: widget.endedCountdownSeconds / 10.0,
                  color: Colors.white,
                  strokeWidth: 2.0,
                ),
                Text(
                  widget.endedCountdownSeconds.toString(),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          );
          barContent = _buildBarContent(
            null,
            "통화 종료",
            widget.callerName,
            widget.number,
            leadingWidget: countdownWidget,
            trailingWidget: IconButton(
              icon: Icon(
                Icons.keyboard_arrow_up,
                color: Colors.white,
                size: 30,
              ),
              onPressed: widget.onTogglePopup,
              padding: EdgeInsets.zero,
              constraints: BoxConstraints(),
            ),
          );
          break;
      }
    }

    // AnimatedContainer가 버튼/바 역할
    return GestureDetector(
      onTap: widget.onTogglePopup,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut, // <<< 커브 변경 (easeOutBack -> easeInOut) 부드럽게
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
            borderRadius: targetBorderRadius,
            onTap: widget.onTogglePopup,
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
                  // <<< 키 값을 isPopupVisible 상태도 포함하도록 수정 >>>
                  child: barContent,
                  key: ValueKey(
                    widget.callState.toString() + isPopupVisible.toString(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 바 내용 생성 헬퍼 (trailingWidget 파라미터 추가)
  Widget _buildBarContent(
    IconData? leadingIcon,
    String status,
    String name,
    String number, {
    Widget? leadingWidget,
    Widget? trailingWidget,
  }) {
    String displayName = name.isNotEmpty ? name : "알 수 없음";
    Color iconColor = Colors.white;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8.0),
          child:
              leadingWidget ??
              (leadingIcon != null
                  ? Icon(leadingIcon, color: iconColor, size: 30)
                  : SizedBox(width: 30)),
        ),
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
        if (trailingWidget != null)
          Padding(
            padding: const EdgeInsets.only(right: 4.0),
            child: trailingWidget,
          ),
        if (trailingWidget == null) SizedBox(width: 42),
      ],
    );
  }
}
