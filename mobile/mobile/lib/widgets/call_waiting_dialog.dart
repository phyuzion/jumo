import 'package:flutter/material.dart';
import 'package:mobile/controllers/search_records_controller.dart';
import 'package:mobile/models/search_result_model.dart';
import 'package:mobile/services/native_methods.dart';
import 'package:mobile/widgets/search_result_widget.dart';
import 'package:provider/provider.dart';
import 'dart:developer';
import 'package:mobile/providers/call_state_provider.dart'; // Added import for CallStateProvider
import 'dart:async'; // Added import for StreamSubscription

/// 통화 중 수신 알림 다이얼로그
class CallWaitingDialog extends StatefulWidget {
  final String phoneNumber;
  final String callerName;
  final VoidCallback? onDismiss;
  // 추가: 각 액션에 대한 콜백
  final VoidCallback? onAccept;
  final VoidCallback? onReject;
  final VoidCallback? onEndAndAccept;

  const CallWaitingDialog({
    Key? key,
    required this.phoneNumber,
    required this.callerName,
    this.onDismiss,
    this.onAccept,
    this.onReject,
    this.onEndAndAccept,
  }) : super(key: key);

  @override
  State<CallWaitingDialog> createState() => _CallWaitingDialogState();
}

class _CallWaitingDialogState extends State<CallWaitingDialog> {
  bool _isLoading = true;
  String? _error;
  SearchResultModel? _searchResult;
  late SearchRecordsController _searchController;
  // 통화 상태 리스너 구독 변수 추가
  StreamSubscription? _callStateSubscription;

  @override
  void initState() {
    super.initState();
    // 초기화를 initState에서 수행
    _searchController = Provider.of<SearchRecordsController>(
      context, 
      listen: false
    );
    _loadSearchResult();
    
    // 통화 상태 변경 감지를 위한 리스너 설정
    final callStateProvider = Provider.of<CallStateProvider>(context, listen: false);
    _startWatchingCallState(callStateProvider);
  }
  
  // 통화 상태 감시 시작
  void _startWatchingCallState(CallStateProvider provider) {
    // 리스너 등록
    _callStateSubscription = Stream.periodic(const Duration(milliseconds: 500))
      .listen((_) => _checkWaitingCallStatus(provider));
    
    log('[CallWaitingDialog] 통화 상태 감시 시작');
  }
  
  // 대기 중인 통화 상태 확인
  void _checkWaitingCallStatus(CallStateProvider provider) {
    if (!mounted) return;
    
    // 현재 수신 중인 전화번호와 표시해야 할 전화번호가 일치하는지 확인
    final ringingCallNumber = provider.ringingCallNumber;
    final currentCallState = provider.callState;
    
    // 기본 조건: 수신 전화가 없거나, 또는 현재 전화번호와 다르거나, 또는 Active 상태가 아니면 팝업 닫기
    bool shouldDismiss = false;
    
    // 1. 수신 전화가 없는 경우
    if (ringingCallNumber == null || ringingCallNumber.isEmpty) {
      shouldDismiss = true;
      log('[CallWaitingDialog] 수신 중인 통화 없음');
    }
    // 2. 현재 표시 중인 전화번호와 수신 전화번호가 다른 경우
    else if (widget.phoneNumber != ringingCallNumber) {
      shouldDismiss = true;
      log('[CallWaitingDialog] 현재 표시($widget.phoneNumber)와 다른 전화번호($ringingCallNumber) 감지');
    }
    // 3. 통화 상태가 active가 아닌 경우
    else if (currentCallState != CallState.active) {
      shouldDismiss = true;
      log('[CallWaitingDialog] 통화 상태가 active가 아님: $currentCallState');
    }
    
    // 다이얼로그를 닫아야 하면 onDismiss 호출
    if (shouldDismiss && widget.onDismiss != null) {
      log('[CallWaitingDialog] 조건에 따라 팝업 닫기');
      widget.onDismiss!();
    }
  }

  @override
  void dispose() {
    // 리스너 정리
    _callStateSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 이미 initState에서 초기화했으므로 여기서는 제거
  }

  Future<void> _loadSearchResult() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final phoneData = await _searchController.searchPhone(widget.phoneNumber);
      if (!mounted) return;
      
      setState(() {
        _searchResult = SearchResultModel(
          phoneNumberModel: phoneData,
          todayRecords: phoneData?.todayRecords ?? [],
        );
        _isLoading = false;
      });
    } catch (e) {
      log('[CallWaitingDialog] Error loading search data: $e');
      if (mounted) {
        setState(() {
          _error = '데이터 로딩 실패';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 발신자 정보 표시 - 이름이 있으면 이름만, 없으면 번호만
    final displayName = widget.callerName.isNotEmpty
        ? widget.callerName
        : widget.phoneNumber;
        
    double panelBorderRadius = 20.0;

    return Material(
      elevation: 4.0,
      borderRadius: BorderRadius.all(Radius.circular(panelBorderRadius)),
      color: Theme.of(context).cardColor,
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: Column(
              children: [
                // 헤더 - 간소화된 발신자 정보
                Padding(
                  padding: const EdgeInsets.only(top: 16.0, bottom: 8.0, left: 8.0, right: 8.0),
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
                
                // 검색 결과 - 남은 모든 공간 차지
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: _buildSearchResultContent(),
                  ),
                ),
                
                // 버튼 영역 - 완전히 아래에 고정
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0, top: 4.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // 대기 후 수신 버튼
                      _buildSmallCallButton(
                        icon: Icons.call,
                        label: '대기 후 수신',
                        color: Colors.green,
                        onTap: _handleAccept,
                      ),
                      // 통화끊고 새로 받기 버튼
                      _buildSmallCallButton(
                        icon: Icons.call_end,
                        label: '통화끊고 받기',
                        color: Colors.orange,
                        onTap: _handleEndAndAccept,
                      ),
                      // 거절 버튼
                      _buildSmallCallButton(
                        icon: Icons.call_end,
                        label: '거절',
                        color: Colors.red,
                        onTap: _handleReject,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // 닫기 버튼
          Positioned(
            top: 8.0,
            right: 8.0,
            child: IconButton(
              icon: const Icon(
                Icons.keyboard_arrow_down,
                color: Colors.grey,
              ),
              onPressed: () {
                if (widget.onDismiss != null) {
                  widget.onDismiss!();
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResultContent() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return Center(
        child: Text(
          _error!,
          style: const TextStyle(color: Colors.red),
        ),
      );
    }

    if (_searchResult == null ||
        _searchResult!.phoneNumberModel == null) {
      return const Center(
        child: Text('검색 결과가 없습니다.'),
      );
    }

    return SearchResultWidget(
      searchResult: _searchResult!,
    );
  }

  // 작은 버튼 위젯 (크기 축소)
  Widget _buildSmallCallButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 50, // 크기 축소
            height: 50, // 크기 축소
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: 24), // 아이콘 크기 축소
          ),
          const SizedBox(height: 2), // 간격 축소
          Text(
            label,
            style: TextStyle(fontSize: 10), // 폰트 크기 축소
          ),
        ],
      ),
    );
  }

  // 기존 _buildCallButton 메서드는 유지 (다른 곳에서 참조할 수 있으므로)
  Widget _buildCallButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return _buildSmallCallButton(
      icon: icon,
      label: label,
      color: color,
      onTap: onTap,
    );
  }

  void _handleAccept() async {
    try {
      log('[CallWaitingDialog] 대기 후 수신 시도 - 현재 통화는 대기 상태로 전환');
      
      // 콜백이 있으면 호출
      if (widget.onAccept != null) {
        widget.onAccept!();
      } else {
        // 직접 네이티브 메서드 호출 (하위 호환성 유지)
        await Provider.of<CallStateProvider>(context, listen: false).acceptWaitingCall();
      }
      
      // 항상 onDismiss 호출하여 다이얼로그 닫기
      if (widget.onDismiss != null) {
        widget.onDismiss!();
      }
    } catch (e) {
      log('[CallWaitingDialog] Error accepting waiting call: $e');
      // 오류 발생해도 다이얼로그 닫기
      if (widget.onDismiss != null && mounted) {
        widget.onDismiss!();
      }
    }
  }

  void _handleReject() async {
    try {
      log('[CallWaitingDialog] 통화 중 수신 거절 시도');
      
      // 콜백이 있으면 호출
      if (widget.onReject != null) {
        widget.onReject!();
      } else {
        // 직접 네이티브 메서드 호출 (하위 호환성 유지)
        await Provider.of<CallStateProvider>(context, listen: false).rejectWaitingCall();
      }
      
      // 항상 onDismiss 호출하여 다이얼로그 닫기
      if (widget.onDismiss != null) {
        widget.onDismiss!();
      }
    } catch (e) {
      log('[CallWaitingDialog] Error rejecting waiting call: $e');
      // 오류 발생해도 다이얼로그 닫기
      if (widget.onDismiss != null && mounted) {
        widget.onDismiss!();
      }
    }
  }

  void _handleEndAndAccept() async {
    try {
      log('[CallWaitingDialog] 현재 통화 끊고 새 통화 수락 시도');
      
      // 콜백이 있으면 호출
      if (widget.onEndAndAccept != null) {
        widget.onEndAndAccept!();
      } else {
        // 직접 네이티브 메서드 호출 (하위 호환성 유지)
        await Provider.of<CallStateProvider>(context, listen: false).endAndAcceptWaitingCall();
      }
      
      // 항상 onDismiss 호출하여 다이얼로그 닫기
      if (widget.onDismiss != null) {
        widget.onDismiss!();
      }
    } catch (e) {
      log('[CallWaitingDialog] Error ending call and accepting waiting call: $e');
      // 오류 발생해도 다이얼로그 닫기
      if (widget.onDismiss != null && mounted) {
        widget.onDismiss!();
      }
    }
  }
} 