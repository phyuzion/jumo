import 'package:flutter/material.dart';
import '../services/native_methods.dart';

class DialerScreen extends StatefulWidget {
  const DialerScreen({super.key});

  @override
  State<DialerScreen> createState() => _DialerScreenState();
}

class _DialerScreenState extends State<DialerScreen> {
  String _number = '';

  void _onDigit(String d) => setState(() => _number += d);

  void _onBackspace() {
    if (_number.isNotEmpty) {
      setState(() => _number = _number.substring(0, _number.length - 1));
    }
  }

  Future<void> _makeCall() async {
    if (_number.isNotEmpty) {
      // 1) 실제 전화 발신
      await NativeMethods.makeCall(_number);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      // Scaffold 없이도 가능.
      // 만약 우상단 검색 아이콘이 필요하면 Row(...)로 배치
      child: Column(
        children: [
          // 상단 우측 검색 아이콘
          Align(
            alignment: Alignment.topRight,
            child: IconButton(
              icon: const Icon(Icons.search),
              onPressed: () {
                Navigator.pushNamed(context, '/search');
              },
            ),
          ),

          // 중간: 번호 표시 + 키패드 + 발신 버튼
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(_number, style: const TextStyle(fontSize: 36)),
                const SizedBox(height: 20),
                _buildDialPad(),
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    shape: const CircleBorder(),
                    padding: const EdgeInsets.all(16),
                    backgroundColor: Colors.green,
                  ),
                  onPressed: _makeCall,
                  child: const Icon(Icons.call, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDialPad() {
    final digits = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['*', '0', '#'],
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children:
            digits.map((row) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children:
                      row.map((d) {
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: GestureDetector(
                              onTap: () => _onDigit(d),
                              child: Container(
                                alignment: Alignment.center,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                child: Text(
                                  d,
                                  style: const TextStyle(
                                    fontSize: 24,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                );
              }).toList()
              ..add(
                // Backspace row
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      onPressed: _onBackspace,
                      icon: const Icon(Icons.backspace),
                      color: Colors.black,
                      iconSize: 32,
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
