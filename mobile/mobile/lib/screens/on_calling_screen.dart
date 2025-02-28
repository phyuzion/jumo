import 'package:flutter/material.dart';
import '../services/native_methods.dart';

class OnCallingScreen extends StatefulWidget {
  const OnCallingScreen({Key? key}) : super(key: key);

  @override
  State<OnCallingScreen> createState() => _OnCallingScreenState();
}

class _OnCallingScreenState extends State<OnCallingScreen> {
  bool isMuted = false;
  bool isHold = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('On Call')),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
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
          ElevatedButton(
            onPressed: NativeMethods.hangUpCall,
            child: const Text('Hang Up'),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleMute() async {
    final newMute = !isMuted;
    await NativeMethods.toggleMute(newMute);
    setState(() => isMuted = newMute);
  }

  Future<void> _toggleHold() async {
    final newHold = !isHold;
    await NativeMethods.toggleHold(newHold);
    setState(() => isHold = newHold);
  }
}
