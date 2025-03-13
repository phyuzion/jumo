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

  // 작성자 정보(기존 글 편집 시)
  String _authorText = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_initialized) {
      if (isNew) {
        // 새 글 작성
        final typeArg = ModalRoute.of(context)?.settings.arguments as int? ?? 0;
        _type = typeArg;
        _titleCtrl.text = '';
        _quillController = QuillController.basic();
      } else {
        // 기존 글 수정
        final item = widget.item!;
        _titleCtrl.text = item['title'] ?? '';
        _type = item['type'] ?? 0;

        // 작성자(userName, userRegion)
        final userName = item['userName'] ?? '(No Name)';
        final userRegion = item['userRegion'] ?? '';
        if (userRegion.isNotEmpty) {
          _authorText = '$userName ($userRegion)';
        } else {
          _authorText = userName;
        }

        // content Delta
        final contentMap = item['content'] as Map<String, dynamic>?;
        if (contentMap != null && contentMap['ops'] is List) {
          final doc = Document.fromJson(contentMap['ops']);
          _quillController = QuillController(
            document: doc,
            selection: const TextSelection.collapsed(offset: 0),
            readOnly: false,
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
          // Title / Type / Author (기존 글 수정 시에만 표시)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                if (!isNew) ...[
                  // 작성자 표시
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '작성자: $_authorText',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                Row(
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
              ],
            ),
          ),

          // 에디터 툴바(심플)
          _buildQuillToolbar(),

          // 에디터
          Expanded(child: _buildQuillEditor()),
        ],
      ),
    );
  }

  Widget _buildQuillToolbar() {
    return QuillSimpleToolbar(
      controller: _quillController!,
      config: const QuillSimpleToolbarConfig(
        embedButtons: [],
        showClipboardPaste: false,
        // bold/italic/underline 등 최소 버튼
      ),
    );
  }

  Widget _buildQuillEditor() {
    return QuillEditor(
      controller: _quillController!,
      focusNode: FocusNode(),
      scrollController: ScrollController(),
      config: const QuillEditorConfig(
        autoFocus: true,
        expands: false,
        padding: EdgeInsets.all(8),
        embedBuilders: [],
      ),
    );
  }
}
