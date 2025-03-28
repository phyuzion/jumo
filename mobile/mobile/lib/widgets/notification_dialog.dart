import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';

class NotificationDialog extends StatelessWidget {
  const NotificationDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final box = GetStorage();
    final displayedNotiIds = List<String>.from(
      box.read('displayedNotiIds') ?? [],
    );

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
                  displayedNotiIds.isEmpty
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
                        itemCount: displayedNotiIds.length,
                        itemBuilder: (context, index) {
                          final noti = box.read('notifications')?[index];
                          if (noti == null) return const SizedBox.shrink();

                          return ListTile(
                            title: Text(noti['title'] ?? ''),
                            subtitle: Text(noti['message'] ?? ''),
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
}
