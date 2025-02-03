import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:get_storage/get_storage.dart';
import '../util/constants.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  final box = GetStorage();

  String _id = '';
  String _expire = '';
  String _name = '';

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  void _loadUserInfo() {
    if (box.read(USER_ID_KEY) != null) {
      _id = box.read(USER_ID_KEY);
      _expire = box.read(USER_EXPIRE) ?? '';
      _name = box.read(USER_NAME) ?? '';
    }
  }

  void _logout() {
    box.erase();
    _id = '';
    _expire = '';
    _name = '';
    FlutterOverlayWindow.closeOverlay();
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('아이디: $_id'),
          const SizedBox(height: 10),
          Text('이름: $_name'),
          const SizedBox(height: 10),
          Text('만기일: ${_expire.isNotEmpty ? formatKST(_expire) : ''}'),
          const SizedBox(height: 20),
          Text('현재 버전: $APP_VERSION'),
          const SizedBox(height: 20),
          OutlinedButton(onPressed: _logout, child: const Text(LOGOUT)),
        ],
      ),
    );
  }
}
