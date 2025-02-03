import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:get_storage/get_storage.dart';

import '../graphql/mutations.dart'; // CLIENT_LOGIN, CREATE_CALL_LOG, UPDATE_CALL_LOG (새로 정의해야 함)
import '../util/constants.dart';

class EditCallDialog extends StatefulWidget {
  final Map<String, dynamic> callLog;
  final bool isNew; // true: 신규 저장, false: 기존 콜로그 수정

  const EditCallDialog({Key? key, required this.callLog, required this.isNew})
    : super(key: key);

  @override
  State<EditCallDialog> createState() => _EditCallDialogState();
}

class _EditCallDialogState extends State<EditCallDialog> {
  late TextEditingController _memoController;
  late TextEditingController _ratingController;
  final box = GetStorage();

  @override
  void initState() {
    super.initState();
    // 신규 저장일 경우, 초기 메모와 별점은 빈 값으로 설정
    _memoController = TextEditingController(
      text: widget.isNew ? "" : widget.callLog["memo"] ?? "",
    );
    _ratingController = TextEditingController(
      text: widget.isNew ? "" : widget.callLog["rating"]?.toString() ?? "",
    );
  }

  @override
  void dispose() {
    _memoController.dispose();
    _ratingController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final String memo = _memoController.text.trim();
    final String ratingStr = _ratingController.text.trim();
    final int? rating = int.tryParse(ratingStr);
    if (rating == null) {
      Fluttertoast.showToast(msg: '별점은 숫자로 입력해주세요.');
      return;
    }

    // Get user credentials from local storage
    final String userId = box.read(USER_ID_KEY) ?? "";
    final String userPhone = box.read(USER_PHONE_KEY) ?? "";

    // GraphQLClient 가져오기
    final client = GraphQLProvider.of(context).value;

    if (widget.isNew) {
      // 신규 저장: createCallLog 뮤테이션 호출
      // 여기서는 callLog에 전달된 전화번호를 customerPhone으로 사용합니다.
      final MutationOptions options = MutationOptions(
        document: gql(CREATE_CALL_LOG),
        variables: {
          'userId': userId,
          'phone': userPhone,
          'customerPhone': widget.callLog["phone"],
          'score': rating,
          'memo': memo,
        },
      );
      try {
        final result = await client.mutate(options);
        if (result.hasException) {
          Fluttertoast.showToast(msg: '저장 실패: ${result.exception.toString()}');
        } else {
          Fluttertoast.showToast(msg: '저장 성공');
        }
      } catch (e) {
        Fluttertoast.showToast(msg: '저장 에러: ${e.toString()}');
      }
    } else {
      // 수정: updateCallLog 뮤테이션 호출
      // callLog에 _id가 포함되어 있다고 가정합니다.
      final MutationOptions options = MutationOptions(
        document: gql(UPDATE_CALL_LOG),
        variables: {
          'logId': widget.callLog["_id"],
          'userId': userId,
          'phone': userPhone,
          'score': rating,
          'memo': memo,
        },
      );
      try {
        final result = await client.mutate(options);
        if (result.hasException) {
          Fluttertoast.showToast(msg: '수정 실패: ${result.exception.toString()}');
        } else {
          Fluttertoast.showToast(msg: '수정 성공');
        }
      } catch (e) {
        Fluttertoast.showToast(msg: '수정 에러: ${e.toString()}');
      }
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.isNew ? "콜로그 저장" : "콜로그 수정"),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 고정: 전화번호와 날짜
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
            // 수정 가능한 별점 (별 아이콘과 함께, 숫자 입력)
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
        TextButton(onPressed: _submit, child: const Text("저장")),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text("취소"),
        ),
      ],
    );
  }
}
