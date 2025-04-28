import 'package:flutter/material.dart';
import 'package:mobile/graphql/contents_api.dart';
import 'package:mobile/utils/constants.dart'; // formatDateString

class BoardListView extends StatefulWidget {
  final String type;
  const BoardListView({Key? key, required this.type}) : super(key: key);

  @override
  State<BoardListView> createState() => BoardListViewState();
}

class BoardListViewState extends State<BoardListView> {
  bool _loading = false;
  List<Map<String, dynamic>> _list = [];

  // 외부에서 강제로 재조회하려고 호출할 메서드
  Future<void> refresh() async {
    await _fetchList();
  }

  @override
  void initState() {
    super.initState();
    _fetchList();
  }

  @override
  void didUpdateWidget(covariant BoardListView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // type 바뀌면 재조회
    if (widget.type != oldWidget.type) {
      _fetchList();
    }
  }

  Future<void> _fetchList() async {
    setState(() => _loading = true);
    try {
      final data = await ContentsApi.getContents(widget.type);

      if (!mounted) return;
      setState(() => _list = data);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _onTapItem(Map<String, dynamic> row) {
    Navigator.pushNamed(
      context,
      '/contentDetail',
      arguments: row['id'],
    ).then((_) => _fetchList()); // 돌아오면 재조회
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_list.isEmpty) {
      return Center(child: Text('게시글이 없습니다. (type=${widget.type})'));
    }

    return RefreshIndicator(
      onRefresh: _fetchList,
      child: ListView.separated(
        itemCount: _list.length,
        separatorBuilder:
            (ctx, i) => const Divider(
              color: Colors.grey,
              thickness: 0.5,
              indent: 16.0,
              endIndent: 16.0,
              height: 0,
            ),
        itemBuilder: (ctx, i) {
          final row = _list[i];
          final title = row['title'] ?? '';
          final userName = row['userName'] ?? '(no name)';
          final createdAt = row['createdAt'] ?? '';
          final dateStr = formatDateString(createdAt);

          // 익명 처리: widget.type 확인
          final displayName = (widget.type == '익명') ? '익명' : userName;

          // 제목 길이에 따라 폰트 크기 동적 적용
          const int titleLengthThreshold = 40;
          final double titleFontSize =
              (title.length > titleLengthThreshold) ? 13 : 16;

          return InkWell(
            onTap: () => _onTapItem(row),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: Row(
                children: [
                  // 왼쪽: 제목 (최대 2줄)
                  Expanded(
                    flex: 3,
                    child: Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: titleFontSize),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // 오른쪽: 작성자(displayName 사용), 날짜(2줄) 오른쪽 정렬
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // 작성자
                        Text(
                          displayName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 4),
                        // 날짜
                        Text(
                          dateStr,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
