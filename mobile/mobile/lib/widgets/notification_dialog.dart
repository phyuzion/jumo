import 'package:flutter/material.dart';
// import 'package:get_storage/get_storage.dart'; // 제거
import 'package:hive_ce/hive.dart'; // Hive 추가
import 'dart:developer'; // 로그 추가

class NotificationDialog extends StatelessWidget {
  const NotificationDialog({super.key});

  @override
  Widget build(BuildContext context) {
    // final box = GetStorage(); // 제거
    // Hive Box 사용
    final notificationBox = Hive.box('notifications');
    // Box에서 데이터 로드 (Map<String, dynamic> 형태로 저장됨)
    // Key는 알림 ID, Value는 알림 데이터 Map
    final notifications = notificationBox.values.toList();
    List<Map<String, dynamic>> notificationList;
    try {
      // 최신 알림이 위로 오도록 정렬 (timestamp 기준, 내림차순)
      notifications.sort((a, b) {
        final timeA = DateTime.tryParse(a?['timestamp'] ?? '');
        final timeB = DateTime.tryParse(b?['timestamp'] ?? '');
        if (timeA == null || timeB == null) return 0;
        return timeB.compareTo(timeA);
      });
      notificationList = notifications.cast<Map<String, dynamic>>().toList();
    } catch (e) {
      log('[NotificationDialog] Error casting notifications: $e');
      notificationList = [];
    }

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

            // 내용
            Flexible(
              child:
                  notificationList
                          .isEmpty // 수정된 변수 사용
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
                        itemCount: notificationList.length, // 수정된 변수 사용
                        itemBuilder: (context, index) {
                          final noti = notificationList[index]; // 수정된 변수 사용
                          return ListTile(
                            title: Text(noti['title'] ?? ''),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(noti['message'] ?? ''),
                                if (noti['timestamp'] != null)
                                  Text(
                                    // 타임스탬프 파싱 및 포맷팅
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
                              // 알림 클릭 시 처리
                            },
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
}
