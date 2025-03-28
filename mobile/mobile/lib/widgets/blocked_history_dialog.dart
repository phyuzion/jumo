import 'package:flutter/material.dart';
import 'package:mobile/models/blocked_history.dart';
import 'package:mobile/controllers/contacts_controller.dart';
import 'package:mobile/utils/constants.dart';
import 'package:provider/provider.dart';

class BlockedHistoryDialog extends StatelessWidget {
  final List<BlockedHistory> history;

  const BlockedHistoryDialog({super.key, required this.history});

  String _formatDate(DateTime dt) {
    return '${dt.month}/${dt.day}';
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _getTypeText(String type) {
    switch (type) {
      case 'danger':
        return '위험번호';
      case 'bomb_calls':
        return '콜폭';
      case 'today':
        return '오늘상담';
      case 'unknown':
        return '모르는번호';
      case 'user':
        return '수동차단';
      default:
        return type;
    }
  }

  @override
  Widget build(BuildContext context) {
    final contactsController = context.read<ContactsController>();
    final contacts = contactsController.getSavedContacts();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.95,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 헤더
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '차단 이력',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            // 리스트
            Expanded(
              child: ListView.builder(
                itemCount: history.length,
                itemBuilder: (context, index) {
                  final item = history[index];
                  // 연락처에서 이름 찾기
                  String? name;
                  for (final c in contacts) {
                    if (normalizePhone(c.phoneNumber) ==
                        normalizePhone(item.phoneNumber)) {
                      name = c.name;
                      break;
                    }
                  }

                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Colors.grey.shade200),
                      ),
                    ),
                    child: Row(
                      children: [
                        // 전화번호와 이름
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.phoneNumber,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (name != null)
                                Text(
                                  name,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        // 일시
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              _formatDate(item.blockedAt),
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.black87,
                              ),
                            ),
                            Text(
                              _formatTime(item.blockedAt),
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 8),
                        // 타입
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _getTypeText(item.type),
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ),
                      ],
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
}
