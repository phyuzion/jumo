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

    // LayoutBuilder와 Column 구조 복원
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenW = constraints.maxWidth;

        return Column(
          // <<< mainAxisAlignment: MainAxisAlignment.end 복원 >>>
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            // 1) 번호 표시 (스타일 복원)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                _number.isEmpty ? ' ' : _number,
                style: const TextStyle(
                  fontSize: 35, // <<< 원래 크기
                  fontWeight: FontWeight.bold, // <<< 원래 굵기
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),

            const SizedBox(height: 20), // <<< 간격 복원
            // 2) 키패드
            _buildDialPad(digits, screenW),

            // 3) 통화 + 백스페이스
            const SizedBox(height: 20), // <<< 간격 복원
            _buildCallRow(screenW),
            const SizedBox(height: 20), // <<< 간격 복원
          ],
        );
      },
    );
  }

  // --- _buildDialPad, _buildDialButton, _buildCallRow 함수 원본 복원 ---
  Widget _buildDialPad(List<List<String>> digits, double screenW) {
    // 버튼 크기/간격 원본 유지
    final buttonSize = screenW / 6.0;
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
    // 스타일 원본 복원
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      child: InkResponse(
        onTap: () => _onDigit(digit),
        highlightShape: BoxShape.circle,
        radius: size / 3,
        child: Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white, // <<< 원래 색상
          ),
          alignment: Alignment.center,
          child: Text(digit, style: const TextStyle(fontSize: 35)), // <<< 원래 크기
        ),
      ),
    );
  }

  Widget _buildCallRow(double size) {
    // 크기 및 구조 원본 복원
    final callButtonSize = 60.0;
    final backspaceSize = 56.0;
    return Row(
      mainAxisSize: MainAxisSize.max,
      children: [
        // <<< Spacer 사용 복원 >>>
        const Spacer(), // 왼쪽 빈 공간
        SizedBox(width: backspaceSize, height: backspaceSize), // 백스페이스 자리 (왼쪽)
        const Spacer(), // 통화 버튼 좌우 균형
        SizedBox(
          width: callButtonSize,
          height: callButtonSize,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              shape: const CircleBorder(),
              padding: EdgeInsets.zero,
              backgroundColor: Colors.green,
            ),
            onPressed: _makeCall,
            child: const Icon(Icons.call, color: Colors.white, size: 28),
          ),
        ),
        const Spacer(), // 통화 버튼 좌우 균형
        if (_number.isNotEmpty)
          InkResponse(
            onTap: _onBackspace,
            highlightShape: BoxShape.circle,
            radius: backspaceSize / 3,
            child: Container(
              width: backspaceSize,
              height: backspaceSize,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white, // <<< 원래 색상
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.backspace, size: 35), // <<< 원래 아이콘/크기
            ),
          )
        else
          SizedBox(width: backspaceSize, height: backspaceSize),
        const Spacer(), // 오른쪽 빈 공간
      ],
    );
  }
}
