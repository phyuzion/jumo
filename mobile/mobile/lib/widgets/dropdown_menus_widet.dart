import 'package:flutter/material.dart';
import 'package:mobile/graphql/client.dart';
import 'package:mobile/widgets/notification_dialog.dart';

class DropdownMenusWidget extends StatelessWidget {
  const DropdownMenusWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      // 사용자가 메뉴를 탭했을 때
      onSelected: (String value) {
        switch (value) {
          case 'notifications':
            showDialog(
              context: context,
              builder: (context) => const NotificationDialog(),
            );
            break;
          case 'reportError':
            // 예: 오류 신고 로직 / 신고 페이지 이동
            Navigator.pushNamed(context, '/reportError');
            break;
          case 'logout':
            GraphQLClientManager.logout();
            break;
        }
      },
      itemBuilder:
          (BuildContext context) => <PopupMenuEntry<String>>[
            const PopupMenuItem<String>(
              value: 'notifications',
              child: Text('알림'),
            ),
            const PopupMenuItem<String>(
              value: 'reportError',
              child: Text('오류 신고'),
            ),
            const PopupMenuItem<String>(value: 'logout', child: Text('로그아웃')),
          ],
      // (선택) 아이콘을 지정하지 않으면 기본 3점 점메뉴처럼 보입니다.
      // child: Icon(Icons.menu),
      icon: const Icon(Icons.menu),
    );
  }
}
