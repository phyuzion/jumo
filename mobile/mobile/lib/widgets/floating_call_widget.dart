import 'package:flutter/material.dart';
import 'package:mobile/screens/home_screen.dart'; // CallState enum 사용 위해 임시 임포트 (나중에 분리)
import 'package:mobile/screens/dialer_screen.dart';
import 'dart:developer';
import 'package:mobile/screens/incoming_call_screen.dart'; // <<< IncomingCallScreen 임포트
// TODO: Import other screen UI widgets (Incoming, OnCall, Ended)

class FloatingCallWidget extends StatelessWidget {
  final bool isVisible; // 팝업 표시 여부
  final CallState callState;
  final String number;
  final String callerName;
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
  Widget build(BuildContext context) {
    double panelBorderRadius = 20.0;

    // --- 확장 팝업 컨텐츠 결정 ---
    Widget popupContent;
    switch (callState) {
      case CallState.idle:
        popupContent = DialerScreen();
        break;
      case CallState.incoming:
        popupContent = IncomingCallScreen(incomingNumber: number);
        break;
      case CallState.active:
        popupContent = Center(
          child: Text(
            "On Call UI Placeholder: $callerName ($number) - $duration s",
          ),
        );
        break;
      case CallState.ended:
        popupContent = Center(
          child: Text("Ended UI Placeholder: $callerName ($number)"),
        );
        break;
      default:
        popupContent = const SizedBox.shrink();
    }

    // isVisible 상태에 따라 투명도만 조절
    return IgnorePointer(
      // 팝업이 안보일때는 탭 이벤트 무시
      ignoring: !isVisible,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: isVisible ? 1.0 : 0.0,
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
                  onPressed: onClosePopup, // 닫기 콜백
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
