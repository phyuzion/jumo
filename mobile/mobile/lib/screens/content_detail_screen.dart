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

  @override
  void initState() {
    super.initState();
    _fetchDetail();
  }

  Future<void> _fetchDetail() async {
    setState(() => _loading = true);
    try {
      final data = await ContentsApi.getSingleContent(widget.contentId);
      if (data != null) {
        _item = data;

        // content = { "ops": [...], ...}
        final contentMap = data['content'];
        if (contentMap != null && contentMap is Map) {
          // parse -> Document.fromJson(contentMap['ops'])
          final opsList = contentMap['ops'];
          if (opsList != null && opsList is List) {
            final doc = Document.fromJson(opsList);
            _quillController = QuillController(
              document: doc,
              selection: const TextSelection.collapsed(offset: 0),
              readOnly: true, // 중요!
            );
          } else {
            // ops가 없음 => empty
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
        appBar: AppBar(title: const Text('상세보기')),
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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Title: ${_item!['title']}'),
          Text('User: ${_item!['userId']}'),
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
          // 댓글
          if (_item!['comments'] != null)
            ..._buildCommentSection(_item!['comments'] as List),
        ],
      ),
    );
  }

  List<Widget> _buildCommentSection(List comments) {
    return [
      Text(
        '댓글 (${comments.length})',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 8),
      for (int i = 0; i < comments.length; i++)
        _buildCommentItem(i, comments[i] as Map<String, dynamic>),
    ];
  }

  Widget _buildCommentItem(int index, Map<String, dynamic> c) {
    final userId = c['userId'] ?? '';
    final comment = c['comment'] ?? '';
    final createdAt = formatDateString(c['createdAt'] ?? '');

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
                  userId,
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
        final arr = [...(_item!['comments'] as List)];
        arr.removeAt(index);
        setState(() => _item!['comments'] = arr);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }
}
