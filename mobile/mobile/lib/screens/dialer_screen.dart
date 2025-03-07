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
      await NativeMethods.makeCall(_number);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 상단 AppBar 없이, 우상단에 검색 아이콘만
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // 1) 상단 검색 아이콘
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                icon: const Icon(Icons.search),
                onPressed: () {
                  // TODO: 검색 화면으로 이동
                },
              ),
            ),
            // 2) 다이얼 표시 영역
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 입력된 번호
                  Text(_number, style: const TextStyle(fontSize: 36)),
                  const SizedBox(height: 20),

                  // 키패드 (1 2 3 / 4 5 6 / 7 8 9 / * 0 #)
                  _buildDialPad(),

                  // 통화 버튼 (중앙)
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
            // 3) 하단 탭(키패드, 최근기록, 연락처, 설정)
            Container(
              color: Colors.white,
              height: 60,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildTabItem('키패드', Icons.dialpad, true),
                  _buildTabItem('최근기록', Icons.history, false),
                  _buildTabItem('연락처', Icons.contacts, false),
                  _buildTabItem('설정', Icons.settings, false),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDialPad() {
    // 간단히 4행 x 3열 Grid로 구성
    // 원한다면 각 숫자 아래에 'ABC', 'DEF' 등 표시 가능
    // 예: Column(children: [Text('1'), Text('ABC', style: ...)])
    final digits = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['*', '0', '#'],
    ];

    return Container(
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
              // 추가로 백스페이스 버튼을 아래처럼 별도 배치하고 싶다면
              ..add(
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

  Widget _buildTabItem(String label, IconData icon, bool selected) {
    // 하단 탭 아이템
    return InkWell(
      onTap: () {
        // TODO: 탭 전환 로직
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: selected ? Colors.black : Colors.grey),
          Text(
            label,
            style: TextStyle(color: selected ? Colors.black : Colors.grey),
          ),
        ],
      ),
    );
  }
}
