import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill_extensions/flutter_quill_extensions.dart';
import 'package:mobile/graphql/contents_api.dart';
import 'package:mobile/repositories/auth_repository.dart';
import 'package:mobile/utils/constants.dart'; // formatDateString()
import 'package:provider/provider.dart';

class ContentDetailScreen extends StatefulWidget {
  final String contentId;
  const ContentDetailScreen({Key? key, required this.contentId})
    : super(key: key);

  @override
  State<ContentDetailScreen> createState() => _ContentDetailScreenState();
}

class _ContentDetailScreenState extends State<ContentDetailScreen> {
  bool _loading = true;
  Map<String, dynamic>? _item;
  QuillController? _quillController;

  final _replyCtrl = TextEditingController();

  String currentUserId = '';

  @override
  void initState() {
    super.initState();
    _initializeScreen();
  }

  Future<void> _initializeScreen() async {
    final authRepository = context.read<AuthRepository>();
    currentUserId = await authRepository.getUserId() ?? '';

    await _fetchDetail();

    if (mounted) {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _fetchDetail() async {
    try {
      final data = await ContentsApi.getSingleContent(widget.contentId);
      if (data != null) {
        _item = data;

        final contentMap = data['content'];
        if (contentMap is Map && contentMap['ops'] is List) {
          final doc = Document.fromJson(contentMap['ops']);
          _quillController = QuillController(
            document: doc,
            selection: const TextSelection.collapsed(offset: 0),
            readOnly: true,
          );
        } else {
          _quillController = QuillController.basic();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  bool get _canEdit {
    if (_item == null) return false;
    final itemUserId = _item!['userId'] as String? ?? '';

    return (itemUserId == currentUserId);
  }

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
        leadingWidth: 30,
        titleSpacing: 0,
        title: _buildHeader(),
        actions: [
          if (_item != null && _canEdit)
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

    return Container(
      color: Colors.grey.shade100,
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildContentCard(),
                  const SizedBox(height: 12),
                  _buildCommentSection(),
                ],
              ),
            ),
          ),

          _buildReplyInput(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final title = _item!['title'] ?? '(제목없음)';
    final userName = _item!['userName'] ?? '(unknown)';
    final createdAtStr = formatKoreanDateTime(_item!['createdAt']);

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  userName,
                  style: const TextStyle(fontSize: 14, color: Colors.black),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                ),
                const SizedBox(height: 4),
                Text(
                  createdAtStr,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
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
            )
          else
            const Text('(내용 없음)'),
        ],
      ),
    );
  }

  Widget _buildCommentSection() {
    final comments = _item!['comments'] as List? ?? [];
    if (comments.isEmpty) {
      return Container(
        margin: const EdgeInsets.only(top: 8),
        child: const Text('댓글 없음', style: TextStyle(color: Colors.grey)),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(
            '댓글 (${comments.length})',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
        const SizedBox(height: 4),
        for (int i = 0; i < comments.length; i++)
          _buildCommentItem(i, comments[i] as Map<String, dynamic>),
      ],
    );
  }

  Widget _buildCommentItem(int index, Map<String, dynamic> c) {
    final userName = c['userName'] ?? '(unknown)';
    final userRegion = c['userRegion'] ?? '';
    final comment = c['comment'] ?? '';
    final createdAtStr = formatDateString(c['createdAt'] ?? '');

    String authorText = userName;
    if (userRegion.isNotEmpty) authorText = '$userName ($userRegion)';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
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
                    createdAtStr,
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
      ),
    );
  }

  Widget _buildReplyInput() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: TextField(
                controller: _replyCtrl,
                decoration: const InputDecoration(
                  hintText: '댓글 입력',
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: _onTapAddReply,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.send, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

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
      final updatedContent = await ContentsApi.createReply(
        contentId: _item!['id'],
        comment: comment,
      );
      if (updatedContent != null) {
        if (!mounted) return;
        setState(() => _item = updatedContent);
      }
      _replyCtrl.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

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
        if (!mounted) return;
        setState(() => _item!['comments'] = arr);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }
}
