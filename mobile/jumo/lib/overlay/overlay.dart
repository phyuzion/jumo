import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:isolate';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:get_storage/get_storage.dart';
import 'package:phone_state/phone_state.dart';

import '../util/constants.dart';

class OverlayView extends StatefulWidget {
  const OverlayView({super.key});

  @override
  State<OverlayView> createState() => _OverlayView();
}

class _OverlayView extends State<OverlayView> {
  final _receivePort = ReceivePort();
  late SendPort _homePort;

  final box = GetStorage();

  bool dragging = false;
  //bool _isListenAlert = false; //for future

  int _overlaySize = 75;

  PhoneState status = PhoneState.nothing();

  @override
  void initState() {
    super.initState();

    _initPorts();

    /// streams message shared between overlay and main app
    FlutterOverlayWindow.overlayListener.listen((event) {
      setState(() {
        _overlaySize = event;
      });
    });
  }

  Future<SendPort> getHomePort() async {
    return _homePort;
  }

  void _initPorts() async {
    if (IsolateNameServer.lookupPortByName(OVERLAY_PORT) != null) {
      IsolateNameServer.removePortNameMapping(OVERLAY_PORT);
    }
    _homePort = await _registerPort(OVERLAY_PORT);
    _receivePort.listen(_portlistener);
  }

  void _portlistener(dynamic message) {
    log(message);
    if (message.toString() == OVERLAY_STATUS_REFRESH_MESSAGE) {
      log('message ARRIVED to Overlay');
    }
  }

  Future<SendPort> _registerPort(String portName) async {
    final sendPort = _receivePort.sendPort;
    IsolateNameServer.registerPortWithName(sendPort, portName);
    return sendPort;
  }

  void _sendMessagetoPort(String str, String port) {
    SendPort? transPort = IsolateNameServer.lookupPortByName(port);
    transPort?.send(str);
  }

  @override
  void dispose() {
    IsolateNameServer.removePortNameMapping(OVERLAY_PORT);

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double sideValue = _overlaySize.toDouble() * 0.05;
    return Center(
      child: Container(
        padding: EdgeInsets.all(sideValue * 2),
        width: _overlaySize.toDouble() * 4,
        height: _overlaySize.toDouble() * 3,
        color: Colors.transparent,
        child: Card(
          color: Colors.white.withOpacity(0.1),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: sideValue),
                  child: Text(
                    '01089236835',
                    style: TextStyle(fontSize: 12, color: Colors.white),
                  ),
                ),
              ),
              Flexible(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: sideValue),
                  child: Text(
                    '별점 : 3 , 토탈콜 : 12',
                    style: TextStyle(fontSize: 12, color: Colors.white),
                  ),
                ),
              ),
              Flexible(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: sideValue),
                  child: Text(
                    'test',
                    style: TextStyle(fontSize: 12, color: Colors.white),
                  ),
                ),
              ),
              /*
              Flexible(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: sideValue),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: ElevatedButton(
                      onPressed: () {
                        FlutterOverlayWindow.closeOverlay();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black.withOpacity(0.2),
                        padding: EdgeInsets.zero,
                      ),
                      child: Icon(
                        Icons.close,
                        color: Colors.white,
                        size: _overlaySize.toDouble() * 0.6,
                      ),
                    ),
                  ),
                ),
              ),
              */
            ],
          ),
        ),
      ),
    );
  }
}
