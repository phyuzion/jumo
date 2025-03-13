import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:mobile/graphql/contents_api.dart';
import 'package:mobile/utils/constants.dart'; // if needed

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

  bool _initialized = false;
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
        _authorText =
            (userRegion.isNotEmpty) ? '$userName ($userRegion)' : userName;

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

  // 드롭다운으로 type 바꾸기 (option)
  void _onChangeType(int? val) {
    if (val == null) return;
    setState(() => _type = val);
  }

  @override
  Widget build(BuildContext context) {
    final appBarTitle = isNew ? '새 글 작성' : '글 수정';

    // 아직 초기화 안 됐으면 로딩
    if (!_initialized || _quillController == null) {
      return Scaffold(
        appBar: AppBar(title: Text(appBarTitle)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      // 키보드가 올라올 때 화면이 잘 올라가도록
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        leadingWidth: 40,
        titleSpacing: 0,
        title: _buildTitleArea(appBarTitle),
        actions: [
          IconButton(icon: const Icon(Icons.check), onPressed: _onSubmit),
        ],
      ),
      backgroundColor: Colors.grey.shade100,
      body: SafeArea(
        child: Column(
          children: [
            // Quill Toolbar (간단버전)
            _buildQuillToolbar(),

            // 본문
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                child: _buildEditorCard(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // AppBar 내 title 부분(좌측에 "새 글 작성"/"글 수정", 우측에 dropdown or etc.)
  Widget _buildTitleArea(String appBarTitle) {
    // 드롭다운 아이템
    const typeItems = [
      DropdownMenuItem(value: 0, child: Text('TYPE_0')),
      DropdownMenuItem(value: 1, child: Text('TYPE_1')),
      DropdownMenuItem(value: 2, child: Text('TYPE_2')),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          Text(
            appBarTitle,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 12),
          // 드롭다운 (type)
          DropdownButton<int>(
            value: _type,
            items: typeItems,
            onChanged: isNew ? _onChangeType : null,
            underline: const SizedBox(),
            style: const TextStyle(fontSize: 14, color: Colors.white),
            dropdownColor: Colors.blueGrey[600],
            iconEnabledColor: Colors.white,
          ),
        ],
      ),
    );
  }

  Widget _buildQuillToolbar() {
    return Container(
      color: Colors.white,
      child: QuillSimpleToolbar(
        controller: _quillController!,
        config: QuillSimpleToolbarConfig(
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
    );
  }

  // 에디터 카드 (제목 + 작성자 + 본문)
  Widget _buildEditorCard() {
    // 작성자 (수정모드일 때만)
    final authorWidget =
        (isNew)
            ? const SizedBox.shrink()
            : Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '작성자: $_authorText',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            );

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
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          // 작성자
          if (!isNew) ...[authorWidget, const SizedBox(height: 12)],
          // 제목 입력
          Row(
            children: [
              const Text(
                'Title:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
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
          const SizedBox(height: 12),
          // Quill Editor
          Container(
            height: 300, // 적당한 높이
            decoration: BoxDecoration(
              color: Colors.grey[50],
              border: Border.all(color: Colors.grey),
            ),
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
