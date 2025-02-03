import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

class EditCallDialog extends StatefulWidget {
  final Map<String, dynamic> callLog;
  const EditCallDialog({Key? key, required this.callLog}) : super(key: key);

  @override
  State<EditCallDialog> createState() => _EditCallDialogState();
}

class _EditCallDialogState extends State<EditCallDialog> {
  late TextEditingController _memoController;
  late TextEditingController _ratingController;

  @override
  void initState() {
    super.initState();
    _memoController = TextEditingController(text: widget.callLog["memo"]);
    _ratingController = TextEditingController(
      text: widget.callLog["rating"].toString(),
    );
  }

  @override
  void dispose() {
    _memoController.dispose();
    _ratingController.dispose();
    super.dispose();
  }

  void _submitEdit() {
    // 여기에 실제 GraphQL updateCallLog 뮤테이션 호출 코드를 추가하면 됩니다.
    // 현재는 placeholder로 토스트 메시지를 표시합니다.
    Fluttertoast.showToast(msg: '수정 기능은 준비 중입니다.');
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("콜로그 수정"),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 전화번호와 날짜는 고정
            Text("전화번호: ${widget.callLog["phone"]}"),
            const SizedBox(height: 8),
            Text("날짜: ${widget.callLog["dateTime"]}"),
            const SizedBox(height: 16),
            // 수정 가능한 메모
            TextField(
              controller: _memoController,
              decoration: const InputDecoration(labelText: "메모"),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            // 수정 가능한 별점 (별 모양 아이콘과 함께)
            Row(
              children: [
                const Icon(Icons.star, color: Colors.amber),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _ratingController,
                    decoration: const InputDecoration(labelText: "별점"),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _submitEdit, child: const Text("저장")),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text("취소"),
        ),
      ],
    );
  }
}
