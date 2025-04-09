import 'package:flutter/material.dart';
import 'package:mobile/services/native_methods.dart';
import 'dart:developer';

// DialerScreen의 UI 및 핵심 로직을 담는 StatefulWidget
class DialerContent extends StatefulWidget {
  const DialerContent({super.key});

  @override
  State<DialerContent> createState() => _DialerContentState();
}

class _DialerContentState extends State<DialerContent> {
  String _number = '';
  static const int _maxDigits = 15;

  /// 숫자 클릭
  void _onDigit(String d) {
    if (_number.length < _maxDigits) {
      if (!mounted) return;
      setState(() => _number += d);
    }
  }

  /// 백스페이스
  void _onBackspace() {
    if (_number.isNotEmpty) {
      if (!mounted) return;
      setState(() => _number = _number.substring(0, _number.length - 1));
    }
  }

  /// 전화걸기
  Future<void> _makeCall() async {
    if (_number.isNotEmpty) {
      log('[DialerContent] Calling: $_number');
      if (!mounted) return;
      await NativeMethods.makeCall(_number);
      // TODO: Notify state change (active)? Close popup?
    }
  }

  @override
  Widget build(BuildContext context) {
    final digits = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['*', '0', '#'],
    ];

    // Scaffold, SafeArea, LayoutBuilder는 제거하고 Column부터 시작
    // 부모(FloatingCallWidget)로부터 크기 제약을 받는다고 가정
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenW = constraints.maxWidth;
        // final screenH = constraints.maxHeight; // 사용하지 않음

        return Column(
          // Column 정렬 방식 변경 (하단 정렬 -> 중앙 부근 배치)
          // mainAxisAlignment: MainAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.spaceEvenly, // 요소들 간 간격 균등 분배
          children: [
            // 1) 번호 표시
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0), // 좌우 패딩
              child: Text(
                _number.isEmpty ? ' ' : _number, // 비었을 때 높이 유지 위해 공백
                style: const TextStyle(
                  fontSize: 30, // 크기 약간 줄임
                  fontWeight: FontWeight.w500, // 굵기 약간 줄임
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),

            // const SizedBox(height: 20), // 제거 (spaceEvenly 사용)

            // 2) 키패드
            _buildDialPad(digits, screenW),

            // 3) 통화 + 백스페이스
            // const SizedBox(height: 20), // 제거
            _buildCallRow(screenW),
            // const SizedBox(height: 20), // 제거
          ],
        );
      },
    );
  }

  // --- _buildDialPad, _buildDialButton, _buildCallRow 함수는 DialerScreen과 동일하게 유지 ---
  Widget _buildDialPad(List<List<String>> digits, double screenW) {
    final buttonSize = screenW / 6.0; // 버튼 크기 계산 유지
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final row in digits)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: row.map((d) => _buildDialButton(d, buttonSize)).toList(),
          ),
      ],
    );
  }

  Widget _buildDialButton(String digit, double size) {
    // 패딩/크기 약간 조정
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkResponse(
        onTap: () => _onDigit(digit),
        highlightShape: BoxShape.circle,
        radius: size / 3.5, // 반응 영역 약간 줄임
        child: Container(
          width: size * 0.9, // 버튼 크기 약간 줄임
          height: size * 0.9,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.grey.shade200, // 배경색 변경
          ),
          alignment: Alignment.center,
          child: Text(digit, style: const TextStyle(fontSize: 30)), // 크기 약간 줄임
        ),
      ),
    );
  }

  Widget _buildCallRow(double size) {
    final callButtonSize = 55.0; // 크기 약간 줄임
    final backspaceSize = 50.0; // 크기 약간 줄임

    return Row(
      mainAxisSize: MainAxisSize.max,
      children: [
        // <<< Spacer 대신 실제 버튼 크기만큼의 SizedBox로 변경 >>>
        SizedBox(width: backspaceSize, height: backspaceSize),
        const Spacer(),
        SizedBox(
          width: callButtonSize,
          height: callButtonSize,
          child: ElevatedButton(
            // ... (스타일 및 onPressed 유지)
            style: ElevatedButton.styleFrom(
              shape: const CircleBorder(),
              padding: EdgeInsets.zero,
              backgroundColor: Colors.green,
            ),
            onPressed: _makeCall,
            child: const Icon(
              Icons.call,
              color: Colors.white,
              size: 26,
            ), // 아이콘 크기 조정
          ),
        ),
        const Spacer(),
        if (_number.isNotEmpty)
          InkResponse(
            // ... (onTap, highlightShape, radius 유지)
            onTap: _onBackspace,
            highlightShape: BoxShape.circle,
            radius: backspaceSize / 3,
            child: Container(
              width: backspaceSize,
              height: backspaceSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.grey.shade200, // 키패드와 동일 스타일
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.backspace_outlined,
                size: 30,
              ), // 아이콘 변경/크기 조정
            ),
          )
        else
          SizedBox(width: backspaceSize, height: backspaceSize),
      ],
    );
  }
}
