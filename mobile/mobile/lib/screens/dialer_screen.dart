import 'package:flutter/material.dart';
import '../services/native_methods.dart';

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
    return SafeArea(
      child: Column(
        children: [
          // 1) 상단 번호 표시 (남는 공간은 Expanded가 차지 -> 번호가 가운데 정렬)
          Expanded(
            child: Center(
              child: Text(_number, style: const TextStyle(fontSize: 36)),
            ),
          ),

          // 2) 키패드
          _buildDialPad(),
          const SizedBox(height: 8),

          // 3) 맨 아래쪽에 백버튼 + 통화버튼 (위에서부터 아래로 쌓음)
          Column(
            children: [
              // 백버튼 (위)
              IconButton(
                icon: const Icon(Icons.backspace),
                iconSize: 40,
                color: Colors.black,
                onPressed: _onBackspace,
              ),
              const SizedBox(height: 16),

              // 통화 버튼 (아래)
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  shape: const CircleBorder(),
                  padding: const EdgeInsets.all(25), // 크기 크게
                  backgroundColor: Colors.green,
                ),
                onPressed: _makeCall,
                child: const Icon(Icons.call, color: Colors.white, size: 32),
              ),
            ],
          ),

          const SizedBox(height: 20), // 아래쪽 여유 공간
        ],
      ),
    );
  }

  Widget _buildDialPad() {
    // 각 줄
    final digits = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['*', '0', '#'],
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children:
          digits.map((row) {
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: row.map((d) => _buildDialButton(d)).toList(),
            );
          }).toList(),
    );
  }

  Widget _buildDialButton(String digit) {
    return Padding(
      padding: const EdgeInsets.all(10.0),
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: () => _onDigit(digit),
        child: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.grey[200],
          ),
          alignment: Alignment.center,
          child: Text(
            digit,
            style: const TextStyle(fontSize: 32, color: Colors.black),
          ),
        ),
      ),
    );
  }
}
