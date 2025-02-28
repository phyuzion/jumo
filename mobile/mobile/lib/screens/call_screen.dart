import 'package:flutter/material.dart';
import '../services/native_methods.dart';

class CallScreen extends StatelessWidget {
  const CallScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 수신(STATE_RINGING) 시 표시
    return Scaffold(
      appBar: AppBar(title: const Text('Incoming Call')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: NativeMethods.acceptCall,
              child: const Text('Accept'),
            ),
            ElevatedButton(
              onPressed: NativeMethods.rejectCall,
              child: const Text('Reject'),
            ),
          ],
        ),
      ),
    );
  }
}
