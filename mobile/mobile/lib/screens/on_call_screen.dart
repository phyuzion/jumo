import 'package:flutter/material.dart';
import '../services/native_methods.dart';

class OnCallScreen extends StatefulWidget {
  const OnCallScreen({super.key});

  @override
  State<OnCallScreen> createState() => _OnCallScreenState();
}

class _OnCallScreenState extends State<OnCallScreen> {
  bool isMuted = false;
  bool isHold = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('On Call')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(isMuted ? 'Muted' : 'Unmuted'),
            Text(isHold ? 'Hold' : 'Not Hold'),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: Icon(isMuted ? Icons.mic_off : Icons.mic),
                  onPressed: _toggleMute,
                ),
                IconButton(
                  icon: Icon(isHold ? Icons.play_arrow : Icons.pause),
                  onPressed: _toggleHold,
                ),
              ],
            ),
            ElevatedButton(onPressed: _hangUp, child: const Text('Hang Up')),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleMute() async {
    final newVal = !isMuted;
    await NativeMethods.toggleMute(newVal);
    setState(() => isMuted = newVal);
  }

  Future<void> _toggleHold() async {
    final newVal = !isHold;
    await NativeMethods.toggleHold(newVal);
    setState(() => isHold = newVal);
  }

  Future<void> _hangUp() async {
    await NativeMethods.hangUpCall();
  }
}
