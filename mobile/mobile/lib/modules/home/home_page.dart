// lib/modules/home/home_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_callkit_incoming/entities/call_kit_params.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:uuid/uuid.dart';

import '../../../core/services/default_dialer_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<StatefulWidget> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _uuid = const Uuid();
  String? _callUuid;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Jumo Phone - Home')),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            ElevatedButton(
              onPressed: _makeFakeIncomingCall,
              child: const Text('Fake Incoming Call'),
            ),
            ElevatedButton(
              onPressed: _endFakeCall,
              child: const Text('End Current Call'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _toggleDefaultDialer,
              child: const Text('Toggle Default Dialer'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _makeFakeIncomingCall() async {
    _callUuid = _uuid.v4();
    final params = CallKitParams(
      id: _callUuid,
      nameCaller: 'Fake Caller',
      appName: 'JumoPhone',
      handle: '010-1234-5678',
      type: 0, // incoming
      textAccept: '수신',
      textDecline: '거절',
      duration: 30000,
    );
    await FlutterCallkitIncoming.showCallkitIncoming(params);
  }

  Future<void> _endFakeCall() async {
    if (_callUuid != null) {
      await FlutterCallkitIncoming.endCall(_callUuid!);
    }
  }

  Future<void> _toggleDefaultDialer() async {
    final isDefault = await DefaultDialerService.isDefaultDialer();
    if (!isDefault) {
      await DefaultDialerService.setDefaultDialer();
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('이미 기본 전화앱입니다.')));
    }
  }
}
