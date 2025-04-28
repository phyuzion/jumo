import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/blocked_number.dart';
import '../controllers/blocked_numbers_controller.dart';

class BlockedNumbersDialog extends StatefulWidget {
  const BlockedNumbersDialog({Key? key}) : super(key: key);

  @override
  State<BlockedNumbersDialog> createState() => _BlockedNumbersDialogState();
}

class _BlockedNumbersDialogState extends State<BlockedNumbersDialog> {
  final _numberController = TextEditingController();
  List<BlockedNumber> _blockedNumbers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBlockedNumbers();
  }

  Future<void> _loadBlockedNumbers() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final numbers =
          await context.read<BlockedNumbersController>().blockedNumbers;
      if (mounted) {
        setState(() {
          _blockedNumbers = numbers;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _addNumber() async {
    if (_numberController.text.isEmpty) return;

    await context.read<BlockedNumbersController>().addBlockedNumber(
      _numberController.text,
    );
    _numberController.clear();
    await _loadBlockedNumbers();
  }

  Future<void> _removeNumber(String number) async {
    await context.read<BlockedNumbersController>().removeBlockedNumber(number);
    await _loadBlockedNumbers();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 헤더
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey.shade200,
            child: Row(
              children: [
                const Icon(Icons.block, color: Colors.red),
                const SizedBox(width: 12),
                const Text(
                  '차단된 전화번호',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          // 전화번호 입력
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _numberController,
                    decoration: const InputDecoration(
                      hintText: '전화번호 입력',
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                ),
                IconButton(icon: const Icon(Icons.add), onPressed: _addNumber),
              ],
            ),
          ),

          // 차단된 번호 목록
          SizedBox(
            height: 300,
            child:
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _blockedNumbers.isEmpty
                    ? const Center(
                      child: Text(
                        '차단된 번호가 없습니다.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                    : ListView.separated(
                      itemCount: _blockedNumbers.length,
                      separatorBuilder:
                          (context, index) => const Divider(
                            color: Colors.grey,
                            thickness: 0.5,
                            indent: 16.0,
                            endIndent: 16.0,
                            height: 0,
                          ),
                      itemBuilder: (context, index) {
                        final number = _blockedNumbers[index];
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          title: Text(
                            number.number,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _removeNumber(number.number),
                          ),
                        );
                      },
                    ),
          ),

          // 닫기 버튼
          InkWell(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              color: Colors.black,
              child: const Center(
                child: Text(
                  '닫기',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _numberController.dispose();
    super.dispose();
  }
}
