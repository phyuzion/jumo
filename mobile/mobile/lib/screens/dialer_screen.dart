import 'package:flutter/material.dart';
import 'package:mobile/services/native_default_dialer_methods.dart';
import 'package:mobile/services/native_methods.dart';
import 'package:mobile/widgets/dropdown_menus_widet.dart';

class DialerScreen extends StatefulWidget {
  const DialerScreen({super.key});

  @override
  State<DialerScreen> createState() => _DialerScreenState();
}

class _DialerScreenState extends State<DialerScreen> {
  String _number = '';
  static const int _maxDigits = 15;

  /// 숫자 클릭
  void _onDigit(String d) {
    if (_number.length < _maxDigits) {
      setState(() => _number += d);
    }
  }

  /// 백스페이스
  void _onBackspace() {
    if (_number.isNotEmpty) {
      setState(() => _number = _number.substring(0, _number.length - 1));
    }
  }

  /// 전화걸기
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

    return Scaffold(
      appBar: AppBar(title: Text('다이얼러')),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final screenW = constraints.maxWidth;
            //final screenH = constraints.maxHeight;

            return Column(
              // 아래부터 쌓아 올림
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // 1) 번호 표시
                Text(_number, style: const TextStyle(fontSize: 35)),

                const SizedBox(height: 30),

                // 2) 키패드
                _buildDialPad(digits, screenW),

                // 3) 통화 + 백스페이스
                const SizedBox(height: 20),
                _buildCallRow(screenW),
                const SizedBox(height: 20),
              ],
            );
          },
        ),
      ),
    );
  }

  /// (A) 키패드
  Widget _buildDialPad(List<List<String>> digits, double screenW) {
    // 버튼 크기/간격 조절
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

  /// 개별 숫자 버튼
  Widget _buildDialButton(String digit, double size) {
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
            color: Colors.white,
          ),
          alignment: Alignment.center,
          child: Text(digit, style: const TextStyle(fontSize: 35)),
        ),
      ),
    );
  }

  /// 통화 버튼은 가운데, 백스페이스는 오른쪽 끝에 (있으면 보이고, 없으면 동일크기의 빈칸)
  Widget _buildCallRow(double size) {
    // 통화 버튼 크기
    final callButtonSize = 60.0;
    // 백스페이스 버튼 크기(키패드와 동일하게 맞출 수도 있음)
    final backspaceSize = 56.0;

    return Row(
      // Row 전체 너비를 화면 가득 차지
      // -> 통화 버튼이 '절대' 화면 중앙에 위치 가능
      mainAxisSize: MainAxisSize.max,
      children: [
        SizedBox(width: backspaceSize, height: backspaceSize),
        SizedBox(width: backspaceSize, height: backspaceSize),
        // 1) 왼쪽 Spacer -> 통화 버튼을 중앙 부근으로
        const Spacer(),

        // 2) 통화 버튼 (고정 크기)
        SizedBox(
          width: callButtonSize,
          height: callButtonSize,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              shape: const CircleBorder(),
              padding: EdgeInsets.zero, // 직접 사이즈를 맞출 것이므로
              backgroundColor: Colors.green,
            ),
            onPressed: _makeCall,
            child: const Icon(Icons.call, color: Colors.white, size: 28),
          ),
        ),

        // 3) 오른쪽 Spacer -> 통화 버튼이 전체 가로폭 중 중앙 위치로
        const Spacer(),

        // 4) 백스페이스 버튼 or 동일 크기 자리
        if (_number.isNotEmpty)
          // 백스페이스 버튼
          InkResponse(
            onTap: _onBackspace,
            highlightShape: BoxShape.circle,
            radius: backspaceSize / 3,
            child: Container(
              width: backspaceSize,
              height: backspaceSize,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white, // 키패드와 동일 스타일 (흰 동그라미)
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.backspace, size: 35),
            ),
          )
        else
          // 동일 자리 차지 -> 통화 버튼이 절대 이동하지 않음
          SizedBox(width: backspaceSize, height: backspaceSize),

        SizedBox(width: backspaceSize, height: backspaceSize),
      ],
    );
  }
}
