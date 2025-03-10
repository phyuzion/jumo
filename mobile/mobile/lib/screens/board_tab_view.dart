// lib/screens/board_tab_view.dart
import 'package:flutter/material.dart';
import 'package:mobile/graphql/contents_api.dart';
import 'package:mobile/utils/constants.dart';

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
      final result = await ContentsApi.getContents(widget.type);
      setState(() => _list = result);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      setState(() => _loading = false);
    }
  }

  void _onTapItem(Map<String, dynamic> row) {
    Navigator.pushNamed(
      context,
      '/contentDetail',
      arguments: row['id'],
    ).then((res) => _fetchList());
  }

  void _onDeleteItem(Map<String, dynamic> row) async {
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
      return Center(child: Text('게시글 없음 (type=${widget.type})'));
    }
    return RefreshIndicator(
      onRefresh: _fetchList,
      child: ListView.builder(
        itemCount: _list.length,
        itemBuilder: (ctx, i) {
          final row = _list[i];
          final title = row['title'] ?? '';
          final id = row['id'] ?? '';
          final userId = row['userId'] ?? '';
          final createdAt = row['createdAt'] ?? '';
          return ListTile(
            title: Text('$title'),
            subtitle: Text(
              'ID: $id / user: $userId\n${formatDateString(createdAt)}',
            ),
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
