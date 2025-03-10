import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:get_storage/get_storage.dart';
import 'package:mobile/controllers/phone_state_controller.dart';
import 'package:mobile/services/native_methods.dart';
import 'package:provider/provider.dart';

class DialerScreen extends StatefulWidget {
  const DialerScreen({super.key});

  @override
  State<DialerScreen> createState() => _DialerScreenState();
}

class _DialerScreenState extends State<DialerScreen> {
  String _number = '';

  Future<void> _makeCall() async {
    if (_number.isNotEmpty) {
      // 앱 발신임을 표시
      /*
      // 2) number 저장
      final box = GetStorage();
      await box.write('search_number', '01089236835');

      // 3) 오버레이 실행
      await FlutterOverlayWindow.showOverlay(
        enableDrag: true,
        alignment: OverlayAlignment.center,
        height: WindowSize.matchParent,
        width: WindowSize.matchParent,
        overlayTitle: "CallResultOverlay",
        overlayContent: "수신전화감지", // 알림 표기용
        flag: OverlayFlag.defaultFlag,
        visibility: NotificationVisibility.visibilityPublic,
        positionGravity: PositionGravity.auto,
      );
*/
      final phoneState = context.read<PhoneStateController>();
      phoneState.outgoingCallFromApp = true;
      await NativeMethods.makeCall(_number);

      if (context.mounted) {
        Navigator.pushNamed(context, '/onCall', arguments: _number);
      }
    }
  }

  void _onDigit(String d) {
    setState(() => _number += d);
  }

  void _onBackspace() {
    if (_number.isNotEmpty) {
      setState(() => _number = _number.substring(0, _number.length - 1));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          const SizedBox(height: 40),
          Text(_number, style: const TextStyle(fontSize: 36)),
          const SizedBox(height: 40),
          Expanded(child: _buildDialPad()),
          Padding(
            padding: const EdgeInsets.only(bottom: 30),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                shape: const CircleBorder(),
                padding: const EdgeInsets.all(32),
                backgroundColor: Colors.green,
              ),
              onPressed: _makeCall,
              child: const Icon(Icons.call, color: Colors.white, size: 32),
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

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children:
            digits.map((row) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children:
                      row.map((d) {
                        return Padding(
                          padding: const EdgeInsets.all(12),
                          child: InkWell(
                            onTap: () => _onDigit(d),
                            child: Container(
                              width: 64,
                              height: 64,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                d,
                                style: const TextStyle(fontSize: 24),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                );
              }).toList()
              ..add(
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.backspace, size: 32),
                      onPressed: _onBackspace,
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
