// lib/screens/content_edit_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:mobile/graphql/contents_api.dart';

class ContentEditScreen extends StatefulWidget {
  final Map<String, dynamic>? item; // null => 새글

  const ContentEditScreen({Key? key, this.item}) : super(key: key);

  @override
  State<ContentEditScreen> createState() => _ContentEditScreenState();
}

class _ContentEditScreenState extends State<ContentEditScreen> {
  bool get isNew => widget.item == null;

  final _titleCtrl = TextEditingController();
  int _type = 0;
  QuillController? _quillController;

  bool _initialized = false; // 한 번만 초기화하기 위한 플래그

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_initialized) {
      // 여기서 ModalRoute.of(context) 접근 가능
      if (isNew) {
        // type 인덱스 받기
        final typeArg = ModalRoute.of(context)?.settings.arguments as int? ?? 0;
        _type = typeArg;
        _titleCtrl.text = '';
        _quillController = QuillController.basic();
      } else {
        // 수정 모드
        _titleCtrl.text = widget.item!['title'] ?? '';
        _type = widget.item!['type'] ?? 0;
        final content = widget.item!['content'] as Map<String, dynamic>?;
        if (content != null && content['ops'] is List) {
          final doc = Document.fromJson(content['ops']);
          _quillController = QuillController(
            readOnly: false,
            document: doc,
            selection: const TextSelection.collapsed(offset: 0),
          );
        } else {
          _quillController = QuillController.basic();
        }
      }

      _initialized = true;
    }
  }

  Future<void> _onSubmit() async {
    if (_quillController == null) return; // 안전 처리

    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('제목을 입력하세요')));
      return;
    }

    // Delta -> { ops: [...] }
    final deltaList = _quillController!.document.toDelta().toJson();
    final contentObj = {'ops': deltaList};

    try {
      if (isNew) {
        final newDoc = await ContentsApi.createContent(
          type: _type,
          title: title,
          delta: contentObj,
        );
        if (newDoc != null) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('작성 완료')));
          Navigator.pop(context, true);
        }
      } else {
        final docId = widget.item!['id'];
        final updated = await ContentsApi.updateContent(
          contentId: docId,
          type: _type,
          title: title,
          delta: contentObj,
        );
        if (updated != null) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('수정 완료')));
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final appBarTitle = isNew ? '새 글 작성' : '글 수정';

    // 아직 didChangeDependencies에서 초기화 안 됐으면 빈 화면
    if (!_initialized || _quillController == null) {
      return Scaffold(
        appBar: AppBar(title: Text(appBarTitle)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(appBarTitle),
        actions: [
          IconButton(icon: const Icon(Icons.check), onPressed: _onSubmit),
        ],
      ),
      body: Column(
        children: [
          // Title / Type 표시
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Text('Type: $_type'),
                const SizedBox(width: 16),
                const Text('Title:'),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _titleCtrl,
                    decoration: const InputDecoration(
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // 툴바(심플)
          QuillSimpleToolbar(
            controller: _quillController!,
            config: const QuillSimpleToolbarConfig(
              embedButtons: [],
              showClipboardPaste: false,

              // bold/italic/underline 등 최소 버튼
            ),
          ),
          // 에디터
          Expanded(
            child: QuillEditor(
              controller: _quillController!,
              focusNode: FocusNode(),
              scrollController: ScrollController(),
              config: const QuillEditorConfig(
                autoFocus: true,
                expands: false,
                padding: EdgeInsets.all(8),
                embedBuilders: [],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
