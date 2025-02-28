import 'package:flutter/material.dart';
import '../services/native_methods.dart';

class IncomingCallScreen extends StatelessWidget {
  final String incomingNumber;
  const IncomingCallScreen({super.key, required this.incomingNumber});

  Future<void> _acceptCall(BuildContext context) async {
    await NativeMethods.acceptCall();
    // 수락 -> 전화가 STATE_ACTIVE -> onCall
    Navigator.pushReplacementNamed(context, '/onCall');
  }

  Future<void> _rejectCall(BuildContext context) async {
    await NativeMethods.rejectCall();
    // 거절 -> STATE_DISCONNECTED -> /callEnded
    Navigator.pop(context); // or Navigator.pushReplacementNamed
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Incoming Call')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Incoming from: $incomingNumber',
              style: const TextStyle(fontSize: 24),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => _acceptCall(context),
              child: const Text('Accept'),
            ),
            ElevatedButton(
              onPressed: () => _rejectCall(context),
              child: const Text('Reject'),
            ),
          ],
        ),
      ),
    );
  }
}
