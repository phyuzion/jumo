// lib/overlays/call_result_overlay.dart

import 'dart:async';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:mobile/models/search_result_model.dart';
import 'package:mobile/widgets/search_result_widget.dart';

class CallResultOverlay extends StatefulWidget {
  const CallResultOverlay({Key? key}) : super(key: key);

  @override
  State<CallResultOverlay> createState() => _CallResultOverlayState();
}

class _CallResultOverlayState extends State<CallResultOverlay> {
  SearchResultModel? _result;
  String? _phoneNumber;

  @override
  void initState() {
    super.initState();

    /// streams message shared between overlay and main app
    FlutterOverlayWindow.overlayListener.listen((result) {
      setState(() {
        final data = result as Map<String, dynamic>;
        _result = SearchResultModel.fromJson(data);
        _phoneNumber =
            _result?.phoneNumberModel?.phoneNumber ?? data['phoneNumber'];
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

    // 데이터 길이에 따른 높이 계산
    final todayRecordsCount = _result?.todayRecords?.length ?? 0;
    final phoneRecordsCount = _result?.phoneNumberModel?.records?.length ?? 0;

    // 기본 높이 (헤더 + 여백)
    double baseHeight = 0.1; // 기본 40% 높이

    // todayRecords가 있는 경우
    if (todayRecordsCount > 0) {
      // todayRecords 섹션 헤더 + 아이템들
      baseHeight += 0.1 + (todayRecordsCount * 0.08);
    }

    // phoneRecords가 있는 경우
    if (phoneRecordsCount > 0) {
      // phoneRecords 섹션 헤더 + 아이템들
      baseHeight += 0.1 + (phoneRecordsCount * 0.08);
    }

    // 최대 높이 제한 (화면의 80%로)
    baseHeight = baseHeight.clamp(0.1, 0.8);

    return Material(
      color: Colors.transparent,
      child: Center(
        child: Container(
          // 가로는 full, 세로는 위에서 계산
          width: size.width,
          height: size.height * baseHeight,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.transparent),
            borderRadius: BorderRadius.circular(5),
          ),
          child: Stack(
            children: [
              if (_result == null)
                const Center(child: CircularProgressIndicator())
              else
                Positioned.fill(
                  child: SearchResultWidget(searchResult: _result!),
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
