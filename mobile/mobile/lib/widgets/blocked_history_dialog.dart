import 'package:flutter/material.dart';
import 'package:mobile/models/blocked_history.dart';
import 'package:mobile/controllers/contacts_controller.dart';
import 'package:mobile/models/phone_book_model.dart';
import 'package:mobile/utils/constants.dart';
import 'package:provider/provider.dart';

class BlockedHistoryDialog extends StatefulWidget {
  final List<BlockedHistory> history;

  const BlockedHistoryDialog({super.key, required this.history});

  @override
  State<BlockedHistoryDialog> createState() => _BlockedHistoryDialogState();
}

class _BlockedHistoryDialogState extends State<BlockedHistoryDialog> {
  late Future<Map<String, PhoneBookModel>> _contactsFuture;

  @override
  void initState() {
    super.initState();
    _contactsFuture = _loadContacts();
  }

  Future<Map<String, PhoneBookModel>> _loadContacts() async {
    final contactsController = context.read<ContactsController>();
    final contactsList = await contactsController.getLocalContacts();
    return {for (var c in contactsList) c.phoneNumber: c};
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
            // 리스트 (FutureBuilder 사용)
            Expanded(
              child: FutureBuilder<Map<String, PhoneBookModel>>(
                future: _contactsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return const Center(child: Text('연락처 정보를 불러올 수 없습니다.'));
                  }

                  final contactsMap = snapshot.data ?? {};

                  return ListView.builder(
                    itemCount: widget.history.length,
                    itemBuilder: (context, index) {
                      final item = widget.history[index];
                      final normalizedNumber = normalizePhone(item.phoneNumber);
                      final contact = contactsMap[normalizedNumber];
                      final name = contact?.name;

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
                                  formatDateOnly(
                                    item.blockedAt.toIso8601String(),
                                  ),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.black87,
                                  ),
                                ),
                                Text(
                                  formatTimeOnly(
                                    item.blockedAt.toIso8601String(),
                                  ),
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
