import 'package:flutter/material.dart';
import 'package:mobile/graphql/contents_api.dart';
import 'package:mobile/utils/constants.dart'; // formatDateString

class BoardTabView extends StatefulWidget {
  final int type;
  const BoardTabView({Key? key, required this.type}) : super(key: key);

  @override
  State<BoardTabView> createState() => _BoardTabViewState();
}

class _BoardTabViewState extends State<BoardTabView> {
  bool _loading = false;
  List<Map<String, dynamic>> _list = [];

  @override
  void initState() {
    super.initState();
    _fetchList();
  }

  Future<void> _fetchList() async {
    setState(() => _loading = true);
    try {
      final data = await ContentsApi.getContents(widget.type);

      // 만약 상태가 dispose 된 뒤라면 중단
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
    ).then((_) => _fetchList());
  }

  Future<void> _onDeleteItem(Map<String, dynamic> row) async {
    final yes = await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('삭제'),
            content: Text('정말 삭제?\nID=${row['id']}'),
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
      final success = await ContentsApi.deleteContent(row['id']);
      if (success) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('삭제 완료')));
        _fetchList();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_list.isEmpty) {
      return Center(child: Text('게시글이 없습니다. (type=${widget.type})'));
    }
    return RefreshIndicator(
      onRefresh: _fetchList,
      child: ListView.builder(
        itemCount: _list.length,
        itemBuilder: (ctx, i) {
          final row = _list[i];
          final title = row['title'] ?? '';
          final userName = row['userName'] ?? '(no name)';
          final userRegion = row['userRegion'] ?? '';
          final createdAt = formatDateString(row['createdAt'] ?? '');

          // 작성자 표시: userName + (userRegion)
          final authorText =
              userRegion.isNotEmpty
                  ? '$userName ($userRegion)'
                  : userName; // region이 비어있으면 userName만

          return ListTile(
            title: Text(title),
            subtitle: Text('Author: $authorText\nCreated: $createdAt'),
            isThreeLine: true,
            onTap: () => _onTapItem(row),
            trailing: IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _onDeleteItem(row),
            ),
          );
        },
      ),
    );
  }
}
