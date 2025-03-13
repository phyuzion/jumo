import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill_extensions/flutter_quill_extensions.dart';
import 'package:mobile/graphql/contents_api.dart';
import 'package:mobile/utils/constants.dart'; // formatDateString

class ContentDetailScreen extends StatefulWidget {
  final String contentId;
  const ContentDetailScreen({Key? key, required this.contentId})
    : super(key: key);

  @override
  State<ContentDetailScreen> createState() => _ContentDetailScreenState();
}

class _ContentDetailScreenState extends State<ContentDetailScreen> {
  bool _loading = false;
  Map<String, dynamic>? _item;
  QuillController? _quillController;

  // 1) 댓글 입력 컨트롤러
  final _replyCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchDetail();
  }

  /// 게시글 + 댓글 목록 불러오기
  Future<void> _fetchDetail() async {
    setState(() => _loading = true);
    try {
      final data = await ContentsApi.getSingleContent(widget.contentId);
      if (data != null) {
        _item = data;

        // content = { "ops": [...] }
        final contentMap = data['content'];
        if (contentMap != null && contentMap is Map) {
          final opsList = contentMap['ops'];
          if (opsList != null && opsList is List) {
            final doc = Document.fromJson(opsList);
            _quillController = QuillController(
              document: doc,
              selection: const TextSelection.collapsed(offset: 0),
              readOnly: true,
            );
          } else {
            _quillController = QuillController.basic();
          }
        } else {
          _quillController = QuillController.basic();
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      setState(() => _loading = false);
    }
  }

  /// 수정 화면
  void _onTapEdit() {
    if (_item == null) return;
    Navigator.pushNamed(context, '/contentEdit', arguments: _item).then((res) {
      if (res == true) {
        _fetchDetail();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _item == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('게시글 상세')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('게시글 상세'),
        actions: [
          if (_item != null)
            IconButton(icon: const Icon(Icons.edit), onPressed: _onTapEdit),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_item == null) {
      return const Center(child: Text('데이터 없음'));
    }

    return Column(
      children: [
        // 상단부 (게시글 정보 + QuillViewer)
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Title: ${_item!['title'] ?? ''}'),

                // userName / userRegion
                _buildAuthorInfo(),

                Text('Type: ${_item!['type']}'),
                Text('Created: ${formatDateString(_item!['createdAt'])}'),
                const SizedBox(height: 16),

                if (_quillController != null)
                  QuillEditor(
                    controller: _quillController!,
                    focusNode: FocusNode(),
                    scrollController: ScrollController(),
                    config: QuillEditorConfig(
                      autoFocus: false,
                      expands: false,
                      padding: EdgeInsets.zero,
                      embedBuilders: [...FlutterQuillEmbeds.editorBuilders()],
                    ),
                  ),
                const Divider(),
                // 댓글 목록
                _buildCommentList(),
              ],
            ),
          ),
        ),
        // 하단 댓글 추가 UI
        _buildReplyInput(),
      ],
    );
  }

  // 게시글 작성자 정보
  Widget _buildAuthorInfo() {
    final userName = _item!['userName'] ?? '(no name)';
    final userRegion = _item!['userRegion'] ?? '';
    String authorText = userName;
    if (userRegion.isNotEmpty) {
      authorText = '$userName ($userRegion)';
    }

    return Text('Author: $authorText');
  }

  /// 댓글 목록
  Widget _buildCommentList() {
    final comments = _item!['comments'] as List? ?? [];
    if (comments.isEmpty) {
      return const Text('댓글 없음');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '댓글 (${comments.length})',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        for (int i = 0; i < comments.length; i++)
          _buildCommentItem(i, comments[i] as Map<String, dynamic>),
      ],
    );
  }

  /// 개별 댓글 아이템
  Widget _buildCommentItem(int index, Map<String, dynamic> c) {
    final userName = c['userName'] ?? '(unknown)';
    final userRegion = c['userRegion'] ?? '';
    final comment = c['comment'] ?? '';
    final createdAt = formatDateString(c['createdAt'] ?? '');

    // 작성자 표시
    String authorText = userName;
    if (userRegion.isNotEmpty) {
      authorText = '$userName ($userRegion)';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  authorText,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(comment),
                const SizedBox(height: 4),
                Text(
                  createdAt,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () => _onDeleteReply(index),
          ),
        ],
      ),
    );
  }

  /// 댓글 입력 + 등록 버튼
  Widget _buildReplyInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.grey.shade100,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _replyCtrl,
              decoration: const InputDecoration(
                labelText: '댓글 입력',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(onPressed: _onTapAddReply, child: const Text('등록')),
        ],
      ),
    );
  }

  /// 댓글 등록 로직
  Future<void> _onTapAddReply() async {
    if (_item == null) return;
    final comment = _replyCtrl.text.trim();
    if (comment.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('댓글을 입력하세요')));
      return;
    }

    try {
      // createReply -> 전체 Content 반환 or comments 반환 (우리 ContentsApi는 전체 Content 반환)
      final updatedContent = await ContentsApi.createReply(
        contentId: _item!['id'],
        comment: comment,
      );
      if (updatedContent != null) {
        setState(() {
          _item = updatedContent;
        });
      }
      _replyCtrl.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  /// 댓글 삭제
  Future<void> _onDeleteReply(int index) async {
    if (_item == null) return;
    final yes = await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('댓글 삭제'),
            content: const Text('정말 삭제하시겠습니까?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('취소'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('확인'),
              ),
            ],
          ),
    );
    if (yes != true) return;

    try {
      final success = await ContentsApi.deleteReply(
        contentId: _item!['id'],
        index: index,
      );
      if (success) {
        final arr = List<Map<String, dynamic>>.from(_item!['comments'] as List);
        arr.removeAt(index);
        setState(() {
          _item!['comments'] = arr;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }
}
