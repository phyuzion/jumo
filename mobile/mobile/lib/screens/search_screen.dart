// lib/screens/search_screen.dart
import 'package:flutter/material.dart';

class SearchScreen extends StatelessWidget {
  const SearchScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 간단 검색 화면
    return Scaffold(
      appBar: AppBar(title: const Text('검색')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: TextField(
          decoration: const InputDecoration(
            labelText: '검색어 입력...',
            prefixIcon: Icon(Icons.search),
          ),
        ),
      ),
    );
  }
}
