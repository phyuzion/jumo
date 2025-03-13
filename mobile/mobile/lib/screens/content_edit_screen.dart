import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill_extensions/flutter_quill_extensions.dart';
import 'package:mobile/graphql/contents_api.dart';

class ContentEditScreen extends StatefulWidget {
  final Map<String, dynamic>? item; // null => 새 글

  const ContentEditScreen({Key? key, this.item}) : super(key: key);

  @override
  State<ContentEditScreen> createState() => _ContentEditScreenState();
}

class _ContentEditScreenState extends State<ContentEditScreen> {
  bool get isNew => widget.item == null;

  int _type = 0;

  final _titleCtrl = TextEditingController();
  QuillController? _quillController;

  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_initialized) {
      if (isNew) {
        // 새 글 작성

        final typeArg = ModalRoute.of(context)?.settings.arguments as int? ?? 0;
        _type = typeArg;
        _titleCtrl.text = ''; // 초기값
        _quillController = QuillController.basic();
      } else {
        // 기존 글 수정
        final item = widget.item!;
        _titleCtrl.text = item['title'] ?? '';

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
    if (_quillController == null) return;
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('제목을 입력하세요')));
      return;
    }

    // Quill Delta -> JSON
    final deltaList = _quillController!.document.toDelta().toJson();
    final contentObj = {'ops': deltaList};

    try {
      if (isNew) {
        final newDoc = await ContentsApi.createContent(
          type: _type, // 필요하다면 특정 type 고정 or 인자 전달
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

    if (!_initialized || _quillController == null) {
      return Scaffold(
        appBar: AppBar(title: Text(appBarTitle)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      // 키보드 올라오면 화면 밀어올리기
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        titleSpacing: 0,
        leadingWidth: 40,
        // (1) AppBar: Title TextField + 작성 버튼(체크)
        title: TextField(
          controller: _titleCtrl,
          style: const TextStyle(fontSize: 18, color: Colors.black),
          decoration: const InputDecoration(
            hintText: '제목을 입력하세요',
            hintStyle: TextStyle(color: Colors.grey),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          ),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.check), onPressed: _onSubmit),
        ],
      ),

      backgroundColor: Colors.grey.shade100,

      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              alignment: Alignment.centerLeft,
              child: Text(
                '현재 게시판: $_type',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),

            // (3) Quill Toolbar
            Container(
              color: Colors.white,
              child: QuillSimpleToolbar(
                controller: _quillController!,
                config: const QuillSimpleToolbarConfig(
                  // 필요한 버튼만 true
                  multiRowsDisplay: false,
                  showDividers: false,
                  showFontFamily: false,
                  showFontSize: true,
                  showBoldButton: true,
                  showItalicButton: true,
                  showLineHeightButton: false,
                  showStrikeThrough: false,
                  showInlineCode: false,
                  showColorButton: false,
                  showBackgroundColorButton: false,
                  showClearFormat: false,
                  showAlignmentButtons: false,
                  showHeaderStyle: false,
                  showListNumbers: false,
                  showListBullets: false,
                  showListCheck: false,
                  showCodeBlock: false,
                  showQuote: false,
                  showIndent: false,
                  showLink: false,
                  showUndo: false,
                  showRedo: false,
                  showDirection: false,
                  showSearchButton: false,
                  showSubscript: false,
                  showSuperscript: false,
                  showClipboardCut: false,
                  showClipboardCopy: false,
                  showClipboardPaste: false,
                ),
              ),
            ),

            // (4) Quill Editor (Expanded)
            Expanded(
              child: Container(
                color: Colors.grey[100],
                child: QuillEditor(
                  controller: _quillController!,
                  focusNode: FocusNode(),
                  scrollController: ScrollController(),

                  config: const QuillEditorConfig(
                    placeholder: '내용을 입력하세요',
                    autoFocus: false,
                    expands: true, // 아래로 확장
                    padding: EdgeInsets.all(8),
                    embedBuilders: [],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
