import 'package:flutter/material.dart';
import '../services/native_methods.dart';

class DialerScreen extends StatefulWidget {
  const DialerScreen({super.key});

  @override
  State<DialerScreen> createState() => _DialerScreenState();
}

class _DialerScreenState extends State<DialerScreen> {
  String _number = '';

  void _onDigit(String d) => setState(() => _number += d);
  void _onBackspace() {
    if (_number.isNotEmpty) {
      setState(() => _number = _number.substring(0, _number.length - 1));
    }
  }

  Future<void> _makeCall() async {
    if (_number.isNotEmpty) {
      await NativeMethods.makeCall(_number);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dialer')),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: Text(_number, style: const TextStyle(fontSize: 36)),
            ),
          ),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            children: [
              for (int i = 1; i <= 9; i++)
                ElevatedButton(
                  onPressed: () => _onDigit('$i'),
                  child: Text('$i', style: const TextStyle(fontSize: 24)),
                ),
              IconButton(
                onPressed: _onBackspace,
                icon: const Icon(Icons.backspace),
              ),
              ElevatedButton(
                onPressed: _makeCall,
                child: const Icon(Icons.call),
              ),
              const SizedBox.shrink(),
            ],
          ),
        ],
      ),
    );
  }
}
