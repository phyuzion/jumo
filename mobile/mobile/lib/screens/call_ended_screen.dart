import 'package:flutter/material.dart';

class CallEndedScreen extends StatelessWidget {
  const CallEndedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Call Ended')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('The call has ended.', style: TextStyle(fontSize: 24)),
            ElevatedButton(
              onPressed:
                  () => Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/dialer',
                    (r) => false,
                  ),
              child: const Text('Back to Dialer'),
            ),
          ],
        ),
      ),
    );
  }
}
