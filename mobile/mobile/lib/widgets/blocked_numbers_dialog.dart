import 'package:flutter/material.dart';
import '../models/blocked_number.dart';
import '../services/blocked_numbers_service.dart';

class BlockedNumbersDialog extends StatefulWidget {
  const BlockedNumbersDialog({Key? key}) : super(key: key);

  @override
  State<BlockedNumbersDialog> createState() => _BlockedNumbersDialogState();
}

class _BlockedNumbersDialogState extends State<BlockedNumbersDialog> {
  final _blockedNumbersService = BlockedNumbersService();
  final _numberController = TextEditingController();
  List<BlockedNumber> _blockedNumbers = [];

  @override
  void initState() {
    super.initState();
    _loadBlockedNumbers();
  }

  void _loadBlockedNumbers() {
    setState(() {
      _blockedNumbers = _blockedNumbersService.getBlockedNumbers();
    });
  }

  Future<void> _addNumber() async {
    if (_numberController.text.isEmpty) return;

    await _blockedNumbersService.addBlockedNumber(_numberController.text);
    _numberController.clear();
    _loadBlockedNumbers();
  }

  Future<void> _removeNumber(String number) async {
    await _blockedNumbersService.removeBlockedNumber(number);
    _loadBlockedNumbers();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('차단된 전화번호'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _numberController,
                  decoration: const InputDecoration(
                    hintText: '전화번호 입력',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.phone,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(icon: const Icon(Icons.add), onPressed: _addNumber),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: ListView.builder(
              itemCount: _blockedNumbers.length,
              itemBuilder: (context, index) {
                final number = _blockedNumbers[index];
                return ListTile(
                  title: Text(number.number),
                  subtitle: Text(
                    '차단일: ${number.blockedAt.toString().split(' ')[0]}',
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () => _removeNumber(number.number),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('닫기'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _numberController.dispose();
    super.dispose();
  }
}
