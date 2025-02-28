import 'package:flutter/material.dart';
import '../services/native_methods.dart';

class DialerScreen extends StatefulWidget {
  const DialerScreen({Key? key}) : super(key: key);

  @override
  State<DialerScreen> createState() => _DialerScreenState();
}

class _DialerScreenState extends State<DialerScreen> {
  String _number = '';

  void _onDigit(String digit) => setState(() => _number += digit);
  void _backspace() {
    if (_number.isNotEmpty) {
      setState(() => _number = _number.substring(0, _number.length - 1));
    }
  }

  Future<void> _makeCall() async {
    if (_number.isNotEmpty) {
      await NativeMethods.makeCall(_number);
      // 발신 → PhoneInCallService onCallAdded (OUTGOING) → 대기 or ACTIVE
      // Navigator.pushNamed(context, '/onCalling'); // 통화중 화면?
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
              child: Text(_number, style: const TextStyle(fontSize: 32)),
            ),
          ),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            children: [
              ...List.generate(9, (i) {
                final digit = '${i + 1}';
                return ElevatedButton(
                  onPressed: () => _onDigit(digit),
                  child: Text(digit, style: const TextStyle(fontSize: 24)),
                );
              }),
              IconButton(
                onPressed: _backspace,
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
