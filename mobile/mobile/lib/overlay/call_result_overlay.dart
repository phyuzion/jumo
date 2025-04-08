// lib/overlays/call_result_overlay.dart

import 'dart:async';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window_sdk34/flutter_overlay_window_sdk34.dart';
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
  final ScrollController _scrollController = ScrollController();

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

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _showOverlay() async {
    log('show Overlay : $_result');
    String title = _phoneNumber!;
    if (await FlutterOverlayWindow.isActive()) {
      await FlutterOverlayWindow.closeOverlay();
    }
    await FlutterOverlayWindow.showOverlay(
      enableDrag: true,
      alignment: OverlayAlignment.bottomCenter,
      height: WindowSize.matchParent,
      width: WindowSize.matchParent,
      overlayTitle: title,
      overlayContent: "전화가 왔습니다", // 알림 표기용
      flag: OverlayFlag.defaultFlag,
      visibility: NotificationVisibility.visibilityPublic,
      positionGravity: PositionGravity.auto,
    );
  }

  void _scrollUp() {
    final newOffset = _scrollController.offset - 100;
    _scrollController.animateTo(
      newOffset.clamp(0, _scrollController.position.maxScrollExtent), // 오버슈팅 방지
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _scrollDown() {
    final newOffset = _scrollController.offset + 100;
    _scrollController.animateTo(
      newOffset.clamp(0, _scrollController.position.maxScrollExtent), // 오버슈팅 방지
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
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
    baseHeight = baseHeight.clamp(0.1, 0.6);

    return Material(
      color: Colors.transparent,
      child: Center(
        child: Container(
          // 가로는 full, 세로는 위에서 계산
          width: size.width,
          height: size.height * baseHeight,
          margin: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.transparent),
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Stack(
              children: [
                if (_result == null)
                  const Center(child: CircularProgressIndicator())
                else
                  Positioned.fill(
                    child: Padding(
                      // 하단 패딩 추가
                      padding: const EdgeInsets.only(
                        bottom: 50,
                      ), // 스크롤 버튼 높이만큼 패딩
                      child: SearchResultWidget(
                        searchResult: _result!,
                        scrollController: _scrollController,
                        ignorePointer: true,
                      ),
                    ),
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
                // 스크롤 버튼들
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 50, // 고정 높이
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      // 그라데이션 추가
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withOpacity(0.0),
                          Colors.white.withOpacity(0.9),
                        ],
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_upward),
                          onPressed: _scrollUp,
                          color: Colors.blue,
                        ),
                        IconButton(
                          icon: const Icon(Icons.arrow_downward),
                          onPressed: _scrollDown,
                          color: Colors.blue,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
