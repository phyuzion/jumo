// lib/screens/danger_numbers_screen.dart
import 'package:flutter/material.dart';
import 'package:mobile/graphql/search_api.dart';
import 'package:mobile/models/phone_number_model.dart';

class DangerNumbersScreen extends StatefulWidget {
  const DangerNumbersScreen({Key? key}) : super(key: key);

  @override
  State<DangerNumbersScreen> createState() => _DangerNumbersScreenState();
}

class _DangerNumbersScreenState extends State<DangerNumbersScreen> {
  bool _loading = false;
  String? _error;
  List<PhoneNumberModel> _numbers = [];

  @override
  void initState() {
    super.initState();
    _fetchDangerNumbers();
  }

  Future<void> _fetchDangerNumbers() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // 예: 위험번호 type=99
      final list = await SearchApi.getPhoneNumbersByType(99);
      setState(() {
        _numbers = list;
      });
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _onRefresh() async {
    await _fetchDangerNumbers();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('위험 번호 목록')),
      body: RefreshIndicator(onRefresh: _onRefresh, child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Text('에러: $_error', style: const TextStyle(color: Colors.red)),
      );
    }
    if (_numbers.isEmpty) {
      return const Center(child: Text('위험 번호가 없습니다.'));
    }
    return ListView.builder(
      itemCount: _numbers.length,
      itemBuilder: (ctx, i) {
        final item = _numbers[i];
        return ListTile(
          title: Text(item.phoneNumber),
          subtitle: Text(
            'type: ${item.type}, records: ${item.records.length}개',
          ),
        );
      },
    );
  }
}
