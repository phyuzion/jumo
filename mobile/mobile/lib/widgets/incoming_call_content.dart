import 'package:flutter/material.dart';
import 'package:mobile/models/search_result_model.dart';
import 'package:mobile/widgets/search_result_widget.dart';
import 'package:mobile/services/native_methods.dart'; // NativeMethods 사용 위해
import 'dart:developer'; // 로그

// IncomingCallScreen의 핵심 UI를 담당하는 Stateless 위젯
class IncomingCallContent extends StatelessWidget {
  final String callerName; // 표시될 이름 (조회 완료된)
  final String number; // 원본 번호
  final SearchResultModel? searchResult; // 검색 결과 (null 가능)
  final bool isLoading; // 데이터 로딩 중 여부
  final String? error; // 데이터 로딩 에러 메시지
  // TODO: 수락/거절 콜백 추가 (단순히 NativeMethods 호출하도록)
  final VoidCallback? onAccept;
  final VoidCallback? onReject;

  const IncomingCallContent({
    super.key,
    required this.callerName,
    required this.number,
    this.searchResult,
    required this.isLoading,
    this.error,
    this.onAccept,
    this.onReject,
  });

  // 수락 버튼 눌렀을 때 실행될 기본 동작
  Future<void> _defaultAcceptCall() async {
    log('[IncomingCallContent] Accept button tapped');
    await NativeMethods.acceptCall();
    // TODO: 상태 업데이트 로직 연결 필요 (팝업 닫기 등)
  }

  // 거절 버튼 눌렀을 때 실행될 기본 동작
  Future<void> _defaultRejectCall() async {
    log('[IncomingCallContent] Reject button tapped');
    await NativeMethods.rejectCall();
    // TODO: 상태 업데이트 로직 연결 필요 (팝업 닫기 등)
  }

  @override
  Widget build(BuildContext context) {
    final displayName = callerName.isNotEmpty ? callerName : number;

    return Column(
      children: [
        // --- 상단 정보 (패딩 최소화) ---
        Padding(
          padding: const EdgeInsets.only(top: 16.0, bottom: 4.0), // 상단 패딩 줄임
          child: Text(
            displayName,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 18, // 크기 약간 줄임
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 8.0), // 하단 패딩 줄임
          child: Text(
            number,
            style: const TextStyle(
              color: Colors.black54,
              fontSize: 13,
            ), // 크기 약간 줄임
          ),
        ),

        // --- 검색 결과 영역 (Expanded 유지) ---
        Expanded(child: _buildBody()),

        // --- 하단 버튼 (텍스트 제거, 패딩 조정) ---
        Padding(
          padding: const EdgeInsets.only(bottom: 12.0, top: 8.0), // 패딩 조정
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildCallButton(
                icon: Icons.call,
                color: Colors.green,
                onTap: onAccept ?? _defaultAcceptCall,
              ),
              _buildCallButton(
                icon: Icons.call_end,
                color: Colors.red,
                onTap: onReject ?? _defaultRejectCall,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // 검색 결과 또는 로딩/에러 표시
  Widget _buildBody() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (error != null) {
      return Center(
        child: Text(error!, style: const TextStyle(color: Colors.red)),
      );
    }
    // SearchResultWidget은 searchResult가 null이어도 처리 가능
    return SearchResultWidget(searchResult: searchResult, ignorePointer: false);
  }

  // 수락/거절 버튼 (라벨 Text 제거)
  Widget _buildCallButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: 30),
      ),
    );
  }
}
