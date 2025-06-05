import 'package:flutter/material.dart';
// import 'package:get_storage/get_storage.dart'; // 제거
// import 'package:hive_ce/hive.dart'; // <<< 제거
import 'dart:developer'; // 로그 추가
import 'package:mobile/repositories/notification_repository.dart'; // <<< 추가
import 'package:provider/provider.dart'; // <<< 추가
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:mobile/utils/app_event_bus.dart';

// <<< StatefulWidget으로 변경 >>>
class NotificationDialog extends StatefulWidget {
  const NotificationDialog({super.key});

  @override
  State<NotificationDialog> createState() => _NotificationDialogState();
}

class _NotificationDialogState extends State<NotificationDialog> {
  List<Map<String, dynamic>> _notificationList = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    try {
      final repository = context.read<NotificationRepository>();

      // 먼저 만료된 알림 제거
      final removedCount = await repository.removeExpiredNotifications();
      if (removedCount > 0) {
        log('[NotificationDialog] Removed $removedCount expired notifications');
      }

      // 알림 로드
      final notifications = await repository.getAllNotifications();

      // 서버에서 가져온 알림 목록 로드 (API에서 최신 상태 확인)
      try {
        final service = FlutterBackgroundService();
        if (await service.isRunning()) {
          log(
            '[NotificationDialog] Requesting fresh notifications from server',
          );
          service.invoke('requestNotifications');
        }
      } catch (e) {
        log(
          '[NotificationDialog] Error requesting notifications from server: $e',
        );
      }

      // 최신 알림이 위로 오도록 정렬
      notifications.sort((a, b) {
        final timeA = DateTime.tryParse(a['timestamp'] ?? '');
        final timeB = DateTime.tryParse(b['timestamp'] ?? '');
        if (timeA == null || timeB == null) return 0;
        return timeB.compareTo(timeA);
      });

      if (mounted) {
        setState(() {
          _notificationList = notifications;
          _isLoading = false;
        });
      }
    } catch (e) {
      log('[NotificationDialog] Error loading notifications: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          // 에러 처리 (예: 빈 리스트 표시)
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // <<< 로딩 상태 및 알림 목록 사용 >>>
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: double.infinity,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 헤더
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '알림',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // 내용 (로딩 상태 처리 추가)
            Flexible(
              child:
                  _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _notificationList.isEmpty
                      ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text(
                            '알림이 없습니다.',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        ),
                      )
                      : ListView.builder(
                        shrinkWrap: true,
                        itemCount: _notificationList.length,
                        itemBuilder: (context, index) {
                          final noti = _notificationList[index];
                          return Dismissible(
                            key: Key(noti['id']?.toString() ?? 'noti_$index'),
                            background: Container(
                              color: Colors.red,
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20.0),
                              child: const Icon(
                                Icons.delete,
                                color: Colors.white,
                              ),
                            ),
                            direction: DismissDirection.endToStart,
                            onDismissed:
                                (_) => _deleteNotification(
                                  noti['id']?.toString() ?? '',
                                ),
                            confirmDismiss: (direction) async {
                              return await showDialog(
                                context: context,
                                builder: (BuildContext context) {
                                  return AlertDialog(
                                    title: const Text('알림 삭제'),
                                    content: const Text('이 알림을 삭제하시겠습니까?'),
                                    actions: <Widget>[
                                      TextButton(
                                        onPressed:
                                            () => Navigator.of(
                                              context,
                                            ).pop(false),
                                        child: const Text('취소'),
                                      ),
                                      TextButton(
                                        onPressed:
                                            () =>
                                                Navigator.of(context).pop(true),
                                        child: const Text(
                                          '삭제',
                                          style: TextStyle(color: Colors.red),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              );
                            },
                            child: ListTile(
                              title: Text(noti['title'] ?? ''),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(noti['message'] ?? ''),
                                  if (noti['timestamp'] != null)
                                    Text(
                                      tryFormatDateTime(noti['timestamp']),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                ],
                              ),
                              leading: const Icon(Icons.notifications),
                              onTap: () {
                                // 알림 클릭 시 처리 (필요 시 구현)
                              },
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (BuildContext context) {
                                      return AlertDialog(
                                        title: const Text('알림 삭제'),
                                        content: const Text('이 알림을 삭제하시겠습니까?'),
                                        actions: <Widget>[
                                          TextButton(
                                            onPressed:
                                                () => Navigator.of(
                                                  context,
                                                ).pop(false),
                                            child: const Text('취소'),
                                          ),
                                          TextButton(
                                            onPressed:
                                                () => Navigator.of(
                                                  context,
                                                ).pop(true),
                                            child: const Text(
                                              '삭제',
                                              style: TextStyle(
                                                color: Colors.red,
                                              ),
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  );

                                  if (confirm == true) {
                                    _deleteNotification(
                                      noti['id']?.toString() ?? '',
                                    );
                                  }
                                },
                              ),
                            ),
                          );
                        },
                      ),
            ),
          ],
        ),
      ),
    );
  }

  // 타임스탬프 포맷팅 헬퍼 함수
  String tryFormatDateTime(String? timestamp) {
    if (timestamp == null) return '';
    try {
      return DateTime.parse(timestamp).toLocal().toString().split('.')[0];
    } catch (_) {
      return timestamp; // 파싱 실패 시 원본 반환
    }
  }

  void _deleteNotification(String id) async {
    if (id.isEmpty) return;

    try {
      final repository = context.read<NotificationRepository>();

      // 노티피케이션 삭제
      await repository.deleteNotificationById(id);
      log('[NotificationDialog] Deleted notification with ID: $id');

      // 목록 다시 로드
      await _loadNotifications();

      // 이벤트 발생 (HomeScreen의 카운트 업데이트를 위해)
      appEventBus.fire(NotificationCountUpdatedEvent());

      // 확인 스낵바 (다이얼로그 내부에서는 보이지 않을 수 있음)
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('알림이 삭제되었습니다.'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      log('[NotificationDialog] Error deleting notification: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('알림 삭제 중 오류가 발생했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
