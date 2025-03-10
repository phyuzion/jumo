// lib/overlays/call_result_overlay.dart

import 'dart:async';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:get_storage/get_storage.dart';
import 'package:mobile/widgets/search_result_widget.dart';

class CallResultOverlay extends StatefulWidget {
  const CallResultOverlay({Key? key}) : super(key: key);

  @override
  State<CallResultOverlay> createState() => _CallResultOverlayState();
}

class _CallResultOverlayState extends State<CallResultOverlay> {
  String? _phoneNumber; // 전달받은 전화번호

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final box = GetStorage();
    _phoneNumber = box.read<String>('search_number');
    log('[CallResultOverlay] stored number=$_phoneNumber');

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
            border: Border.all(color: Colors.black26),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Stack(
            children: [
              // (1) 검색결과
              if (_phoneNumber == null)
                const Center(child: CircularProgressIndicator())
              else
                Positioned.fill(
                  child: SearchResultWidget(phoneNumber: _phoneNumber!),
                ),

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
