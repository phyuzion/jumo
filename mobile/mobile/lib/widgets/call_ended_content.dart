import 'package:flutter/material.dart';
import 'dart:developer';
import 'package:provider/provider.dart'; // 컨트롤러 접근 위해
import 'package:mobile/controllers/blocked_numbers_controller.dart';
import 'package:mobile/screens/edit_contact_screen.dart'; // 편집 화면 이동
import 'package:mobile/utils/constants.dart'; // normalizePhone
import 'package:mobile/services/native_methods.dart'; // <<< NativeMethods 임포트 추가
import 'package:mobile/providers/call_state_provider.dart'; // CallStateProvider 접근 추가

// CallEndedScreen의 핵심 UI를 담당하는 위젯
class CallEndedContent extends StatelessWidget {
  final String callerName;
  final String number;
  final String reason; // 'missed' or 'ended' etc.

  const CallEndedContent({
    super.key,
    required this.callerName,
    required this.number,
    required this.reason,
  });

  // 편집 버튼 탭 핸들러
  Future<void> _onTapEdit(
    BuildContext context,
    String number,
    String? displayName,
  ) async {
    final norm = normalizePhone(number);
    // EditContactScreen으로 로드된 이름과 정규화된 번호 전달
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => EditContactScreen(
              initialName: displayName ?? '',
              initialPhone: norm,
            ),
      ),
    );
    // TODO: 편집 후 돌아왔을 때 상태 갱신 필요 시 로직 추가 (팝업 내에서는 불필요할수도)
  }

  // 차단 버튼 탭 핸들러
  Future<void> _onTapBlock(BuildContext context, String number) async {
    final normalizedNumber = normalizePhone(number);
    final blocknumbersController = context.read<BlockedNumbersController>();
    try {
      await blocknumbersController.addBlockedNumber(normalizedNumber);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('전화번호가 차단되었습니다.'),
            duration: Duration(seconds: 2),
          ),
        );
        // TODO: Close popup after blocking? (Notify HomeScreen)
      }
    } catch (e) {
      log('[CallEndedContent] Error blocking number: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('차단 중 오류 발생: $e')));
      }
    }
  }

  // 검색 버튼 탭 핸들러
  void _onTapSearch(BuildContext context, String number) {
    Navigator.pushNamed(
      context,
      '/search',
      arguments: {'number': normalizePhone(number), 'isRequested': false},
    );
    // TODO: Close popup after navigation? (Notify HomeScreen)
  }

  // <<< 전화 걸기 핸들러 추가 >>>
  Future<void> _onTapCall(BuildContext context, String number) async {
    log('[CallEndedContent] Call button tapped for $number');
    await NativeMethods.makeCall(number);
    // TODO: Close popup? (Notify HomeScreen)
  }

  // <<< 문자 보내기 핸들러 추가 >>>
  Future<void> _onTapMessage(BuildContext context, String number) async {
    log('[CallEndedContent] Message button tapped for $number');
    await NativeMethods.openSmsApp(number);
    // TODO: Close popup?
  }

  // 닫기 버튼 핸들러 추가
  void _onTapClose(BuildContext context) {
    log('[CallEndedContent] Close button tapped, resetting state to idle');
    // CallStateProvider의 resetState 호출하여 idle 상태로 전환
    final callStateProvider = Provider.of<CallStateProvider>(context, listen: false);
    callStateProvider.resetState();
  }

  @override
  Widget build(BuildContext context) {
    // <<< 전달받은 reason 값 로깅 추가 >>>
    log('[CallEndedContent] Received reason: $reason');
    final displayName = callerName.isNotEmpty ? callerName : number;

    // <<< 상태 메시지 및 색상 결정 로직 추가 >>>
    String statusMessage;
    Color statusColor;
    if (reason == 'missed') {
      statusMessage = '부재중 전화';
      statusColor = Colors.orange;
    } else {
      statusMessage = '통화 종료';
      statusColor = Colors.red;
    }

    return Stack(
      children: [
        // 기존 UI
        Column(
          children: [
            // --- 상단 정보 (컴팩트하게, 폰트 크기 다시 키움) ---
            Padding(
              padding: const EdgeInsets.only(top: 16.0, bottom: 4.0),
              child: Text(
                displayName,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Text(
                number,
                style: const TextStyle(color: Colors.black54, fontSize: 16),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Text(
                statusMessage, // <<< 계산된 메시지 사용
                style: TextStyle(
                  fontSize: 18,
                  color: statusColor,
                  fontWeight: FontWeight.w500,
                ), // <<< 계산된 색상 사용
              ),
            ),

            const Spacer(),

            // --- 하단 액션 버튼 (2줄 구조로 변경) ---
            Padding(
              padding: const EdgeInsets.only(bottom: 20.0, top: 10.0),
              child: Column(
                // <<< Row -> Column
                children: [
                  // --- 첫 번째 줄: 전화, 문자 ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      SizedBox(width: 40), // 간격 맞추기용 빈 공간
                      _buildActionButton(
                        icon: Icons.call, // 전화 아이콘
                        color: Colors.green, // 전화 색상
                        label: '전화',
                        onTap: () => _onTapCall(context, number),
                      ),
                      SizedBox(width: 20), // 간격 맞추기용 빈 공간
                      _buildActionButton(
                        icon: Icons.message, // 문자 아이콘
                        color: Colors.blue, // 문자 색상
                        label: '문자',
                        onTap: () => _onTapMessage(context, number),
                      ),
                      SizedBox(width: 40), // 간격 맞추기용 빈 공간
                    ],
                  ),
                  const SizedBox(height: 15), // <<< 줄 간격 추가
                  // --- 두 번째 줄: 검색, 편집, 차단 ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildActionButton(
                        icon: Icons.search,
                        color: Colors.orange,
                        label: '검색',
                        onTap: () => _onTapSearch(context, number),
                      ),
                      _buildActionButton(
                        icon: Icons.edit,
                        color: Colors.blueGrey,
                        label: '편집',
                        onTap: () => _onTapEdit(context, number, callerName),
                      ),
                      _buildActionButton(
                        icon: Icons.block,
                        color: Colors.red,
                        label: '차단',
                        onTap: () => _onTapBlock(context, number),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        
        // 왼쪽 위에 X 버튼 추가 (동그라미 안에)
        Positioned(
          top: 12.0,
          left: 12.0,
          child: GestureDetector(
            onTap: () => _onTapClose(context),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close,
                color: Colors.black87,
                size: 24,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // 액션 버튼 빌더 (CallEndedScreen 스타일 참고)
  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 55, // 크기 약간 작게
            height: 55,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: 28), // 크기 약간 작게
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(color: Colors.black87, fontSize: 12),
        ),
      ],
    );
  }
}
