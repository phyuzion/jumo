// lib/modules/phone/calling_page.dart

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';

import '../../../navigation/navigation_service.dart';

class CallingPage extends StatefulWidget {
  const CallingPage({super.key});

  @override
  State<CallingPage> createState() => CallingPageState();
}

class CallingPageState extends State<CallingPage> {
  CallKitParams? calling;
  Timer? _timer;
  int _callDuration = 0;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args != null) {
      final mapData = jsonDecode(jsonEncode(args)) as Map<String, dynamic>;
      calling = CallKitParams.fromJson(mapData);
    }

    final timeStr = _formatTime(_callDuration);

    return Scaffold(
      appBar: AppBar(title: const Text('Calling...')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('통화 중: $timeStr', style: const TextStyle(fontSize: 24)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fakeConnected,
              child: const Text('Fake Connected Call'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: _endCall,
              child: const Text('End Call'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _fakeConnected() async {
    if (calling == null) return;
    await FlutterCallkitIncoming.setCallConnected(calling!.id!);
    _startTimer();
  }

  Future<void> _endCall() async {
    if (calling == null) return;
    await FlutterCallkitIncoming.endCall(calling!.id!);
    NavigationService.instance.goBack();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _callDuration++;
      });
    });
  }

  String _formatTime(int sec) {
    final h = sec ~/ 3600;
    final m = (sec % 3600) ~/ 60;
    final s = sec % 60;
    return '${_twoDigits(h)}:${_twoDigits(m)}:${_twoDigits(s)}';
  }

  String _twoDigits(int n) => n.toString().padLeft(2, '0');

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
