import 'package:flutter/material.dart';
import 'package:mobile/services/native_methods.dart';

class DialerScreen extends StatefulWidget {
  const DialerScreen({super.key});

  @override
  State<DialerScreen> createState() => _DialerScreenState();
}

class _DialerScreenState extends State<DialerScreen> {
  String _number = '';

  void _onDigit(String d) {
    setState(() => _number += d);
  }

  void _onBackspace() {
    if (_number.isNotEmpty) {
      setState(() => _number = _number.substring(0, _number.length - 1));
    }
  }

  Future<void> _makeCall() async {
    if (_number.isNotEmpty) {
      await NativeMethods.makeCall(_number);
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

    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          // 화면 높이/너비
          final screenW = constraints.maxWidth;
          final screenH = constraints.maxHeight;

          return Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // 1) 전화번호 표시 영역
              Padding(
                padding: EdgeInsets.only(top: screenH * 0.02),
                child: Text(_number, style: const TextStyle(fontSize: 30)),
              ),

              // 2) 다이얼 패드 (Expanded로 키워 세로 공간 유연 확보)
              Expanded(child: Center(child: _buildDialPad(digits, screenW))),

              // 3) 통화 버튼
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    shape: const CircleBorder(),
                    padding: const EdgeInsets.all(24),
                    backgroundColor: Colors.green,
                  ),
                  onPressed: _makeCall,
                  child: const Icon(Icons.call, color: Colors.white, size: 32),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// 원형 버튼 여러 개(4행x3열 + 백스페이스)를 만드는 메서드
  Widget _buildDialPad(List<List<String>> digits, double screenW) {
    // 화면 폭에 맞춰 버튼 크기를 적당히 계산
    // 여기서는 "한 행에 3개 버튼" 기준으로, 남는 여유를 조금 주는 방식
    final buttonSize = screenW / 6; // 적절히 조정

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < digits.length; i++)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children:
                digits[i].map((d) {
                  return _buildDialButton(d, buttonSize);
                }).toList(),
          ),
        // 마지막 줄에 백스페이스 버튼만 넣기
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [_buildBackspaceButton(buttonSize)],
        ),
      ],
    );
  }

  Widget _buildDialButton(String digit, double size) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: InkResponse(
        onTap: () => _onDigit(digit),
        // InkResponse: 원형 리플 효과
        highlightShape: BoxShape.circle,
        radius: size / 3, // 원형 범위
        child: Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
          ),
          alignment: Alignment.center,
          child: Text(digit, style: const TextStyle(fontSize: 35)),
        ),
      ),
    );
  }

  Widget _buildBackspaceButton(double size) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: InkResponse(
        onTap: _onBackspace,
        highlightShape: BoxShape.circle,
        radius: size / 3,
        child: Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
          ),
          alignment: Alignment.center,
          child: const Icon(Icons.backspace, size: 35),
        ),
      ),
    );
  }
}
