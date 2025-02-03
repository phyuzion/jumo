import 'dart:io';
import 'dart:isolate';
import 'dart:ui';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:get_storage/get_storage.dart';
import 'package:jumo/pages/latestPage.dart';
import 'package:jumo/pages/searchPage.dart';
import 'update_controller.dart';
import 'package:permission_handler/permission_handler.dart';
import '../pages/account.dart';
import '../util/constants.dart';

class Controller extends StatefulWidget {
  const Controller({key}) : super(key: key);

  @override
  State<Controller> createState() => _ControllerState();
}

class _ControllerState extends State<Controller>
    with SingleTickerProviderStateMixin {
  late UpdateController _updateController;
  late TabController _tabController;
  final box = GetStorage();

  final _receivePort = ReceivePort();
  late SendPort _homePort;

  int _overlaySize = 75;

  bool _isPermissionReady = false;

  late AccountPage _accountPage;
  late LatestPage _latestPage;
  late SearchPage _searchPage;

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: 3, vsync: this);
    _updateController = UpdateController();

    _accountPage = const AccountPage();
    _latestPage = const LatestPage();
    _searchPage = const SearchPage();

    _checkPermission();
    _initPorts();
  }

  Future<bool> showConfirmationDialog(BuildContext context) async {
    return await showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('종료'),
            content: const Text('종료하시겠습니까?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('아니오'),
              ),
              TextButton(
                onPressed: () {
                  FlutterOverlayWindow.closeOverlay();
                  Navigator.of(context).pop(true);
                  exit(0);
                },
                child: const Text('네'),
              ),
            ],
          ),
    );
  }

  Future<void> showOverlay() async {
    if (await FlutterOverlayWindow.isActive()) return;
    await FlutterOverlayWindow.showOverlay(
      enableDrag: true,
      overlayTitle: "GXG_OVERLAY",
      overlayContent: 'Overlay Enabled',
      flag: OverlayFlag.defaultFlag,
      alignment: OverlayAlignment.center,
      visibility: NotificationVisibility.visibilityPublic,
      positionGravity: PositionGravity.none,
      width: _overlaySize * 3,
      height: _overlaySize * 6,
    );
  }

  void _portListener(dynamic message) {
    log('Controller getMessage : $message');

    //for future....
    if (message.toString() == "setting") {
      sendIsolateMessage(SETTING_PORT, "success");
    }
  }

  void sendIsolateMessage(String port, String str) {
    SendPort? transPort = IsolateNameServer.lookupPortByName(port);
    transPort?.send(str);
  }

  void _initPorts() async {
    if (IsolateNameServer.lookupPortByName(CONTROLLER_PORT) != null) {
      IsolateNameServer.removePortNameMapping(CONTROLLER_PORT);
    }
    _homePort = await _registerPort(CONTROLLER_PORT);
    _receivePort.listen(_portListener);
  }

  Future<SendPort> getHomePort() async {
    return _homePort;
  }

  Future<SendPort> _registerPort(String portName) async {
    final sendPort = _receivePort.sendPort;
    IsolateNameServer.registerPortWithName(sendPort, portName);
    return sendPort;
  }

  Future<void> _checkPermission() async {
    bool overlayGranted = false;
    bool phoneStateGranted = false;

    overlayGranted = await FlutterOverlayWindow.isPermissionGranted();
    if (!overlayGranted) {
      await FlutterOverlayWindow.requestPermission();
    }

    overlayGranted = await FlutterOverlayWindow.isPermissionGranted();

    final phoneStateStatus = await Permission.phone.status;
    if (phoneStateStatus.isDenied) {
      await Permission.phone.request();
    }
    phoneStateGranted = phoneStateStatus.isGranted;

    if (overlayGranted && phoneStateGranted) {
      setState(() {
        _isPermissionReady = true;
        //_updateController.checkVersion();
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    IsolateNameServer.removePortNameMapping(CONTROLLER_PORT);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () => showConfirmationDialog(context),
      child:
          _isPermissionReady
              ? Scaffold(
                appBar: AppBar(
                  title: TabBar(
                    controller: _tabController,
                    tabs: const [
                      Tab(text: LATEST_TAB),
                      Tab(text: SEARCH_TAB),
                      Tab(text: ACCOUNT_TAB),
                    ],
                  ),
                ),
                body: TabBarView(
                  physics: const NeverScrollableScrollPhysics(),
                  controller: _tabController,
                  children: [_latestPage, _searchPage, _accountPage],
                ),
              )
              : Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 30),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          if (!_isPermissionReady) {
                            _checkPermission();
                          }
                        });
                      },
                      child: const Text(CHECK_PERMISSION),
                    ),
                  ],
                ),
              ),
    );
  }
}
