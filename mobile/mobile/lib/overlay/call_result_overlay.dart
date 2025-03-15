// lib/overlays/call_result_overlay.dart

import 'dart:async';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:mobile/models/phone_number_model.dart';
import 'package:mobile/widgets/search_result_widget.dart';

class CallResultOverlay extends StatefulWidget {
  const CallResultOverlay({Key? key}) : super(key: key);

  @override
  State<CallResultOverlay> createState() => _CallResultOverlayState();
}

class _CallResultOverlayState extends State<CallResultOverlay> {
  PhoneNumberModel? _result;
  bool _isNew = false;
  String? _phoneNumber;

  @override
  void initState() {
    super.initState();

    /// streams message shared between overlay and main app
    FlutterOverlayWindow.overlayListener.listen((result) {
      setState(() {
        final phoneNumberData = result as Map<String, dynamic>;
        // 일단 isNew 여부를 먼저 확인
        _isNew = phoneNumberData['isNew'] == true;
        _phoneNumber = phoneNumberData['phoneNumber'] as String?;
        if (!_isNew) {
          _result = PhoneNumberModel.fromJson(phoneNumberData);
          _phoneNumber = _result?.phoneNumber;
        }
      });
      _showOverlay();
    });
  }

  Future<void> _showOverlay() async {
    log('show Overlay : $_result');
    String title = _phoneNumber!;
    await FlutterOverlayWindow.showOverlay(
      enableDrag: true,
      alignment: OverlayAlignment.center,
      height: WindowSize.matchParent,
      width: WindowSize.matchParent,
      overlayTitle: title,
      overlayContent: "전화가 왔습니다", // 알림 표기용

      flag: OverlayFlag.defaultFlag,
      visibility: NotificationVisibility.visibilityPublic,
      positionGravity: PositionGravity.auto,
    );
  }

  @override
  Widget build(BuildContext context) {
    // 가로/세로에 따라 높이 지정
    final size = MediaQuery.of(context).size;

    return Material(
      color: Colors.transparent,
      child: Center(
        child: Container(
          // 가로는 full, 세로는 위에서 계산
          width: size.width,
          height: size.height * 0.4,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.transparent),
            borderRadius: BorderRadius.circular(5),
          ),
          child: Stack(
            children: [
              if (_isNew)
                // 신규
                Column(
                  children: [
                    const SizedBox(height: 100),
                    Text(
                      _phoneNumber!,
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '신규입니다.',
                      style: const TextStyle(color: Colors.black, fontSize: 16),
                    ),
                  ],
                )
              else ...[
                if (_result == null)
                  const Center(child: CircularProgressIndicator())
                else
                  Positioned.fill(
                    child: SearchResultWidget(phoneNumberModel: _result!),
                  ),
              ],
              // (2) 닫기 버튼
              Positioned(
                top: 0,
                right: 0,
                child: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => FlutterOverlayWindow.closeOverlay(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
