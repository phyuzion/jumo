import 'package:flutter/material.dart';
import 'package:mobile/models/blocked_history.dart';
import 'package:mobile/controllers/contacts_controller.dart';
import 'package:mobile/models/phone_book_model.dart';
import 'package:mobile/utils/constants.dart';
import 'package:provider/provider.dart';
import 'dart:developer'; // log 사용을 위해 추가

class BlockedHistoryDialog extends StatefulWidget {
  final List<BlockedHistory> history;

  const BlockedHistoryDialog({super.key, required this.history});

  @override
  State<BlockedHistoryDialog> createState() => _BlockedHistoryDialogState();
}

class _BlockedHistoryDialogState extends State<BlockedHistoryDialog> {
  // _contactsFuture는 이제 Map을 직접 들고 있도록 변경, 또는 FutureBuilder 제거 고려
  Map<String, PhoneBookModel> _contactsMap = {};
  bool _isLoadingContacts = true; // 로딩 상태 추가

  @override
  void initState() {
    super.initState();
    _loadContactsMap();
  }

  Future<void> _loadContactsMap() async {
    if (!mounted) return;
    setState(() {
      _isLoadingContacts = true;
    });
    try {
      final contactsController = context.read<ContactsController>();
      // getLocalContacts 대신 contacts getter 사용
      final contactsList = contactsController.contacts;
      _contactsMap = {
        for (var c in contactsList) normalizePhone(c.phoneNumber): c,
      }; // phoneNumber도 normalize
      log(
        '[BlockedHistoryDialog] Loaded ${_contactsMap.length} contacts into map.',
      );
    } catch (e) {
      log('[BlockedHistoryDialog] Error loading contacts: $e');
      _contactsMap = {}; // 오류 시 빈 맵
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingContacts = false;
        });
      }
    }
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
            Expanded(
              child:
                  _isLoadingContacts
                      ? const Center(child: CircularProgressIndicator())
                      : widget.history.isEmpty
                      ? const Center(child: Text('차단 이력이 없습니다.'))
                      : ListView.builder(
                        itemCount: widget.history.length,
                        itemBuilder: (context, index) {
                          final item = widget.history[index];
                          final normalizedNumber = normalizePhone(
                            item.phoneNumber,
                          );
                          final contact = _contactsMap[normalizedNumber];
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
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.phoneNumber,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      if (name != null &&
                                          name.isNotEmpty) // 이름이 있을 때만 표시
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
