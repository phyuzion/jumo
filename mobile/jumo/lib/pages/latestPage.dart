import 'package:flutter/material.dart';
import 'recent_call_tab.dart';
import 'my_record_tab.dart';

class LatestPage extends StatelessWidget {
  const LatestPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: const TabBar(tabs: [Tab(text: "최근 기록"), Tab(text: "내 기록")]),

        body: const TabBarView(children: [RecentCallTab(), MyRecordTab()]),
      ),
    );
  }
}
