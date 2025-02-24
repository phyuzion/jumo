// lib/modules/phone/incoming_call_page.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import '../../navigation/navigation_service.dart';
import '../../navigation/app_router.dart';

class IncomingCallPage extends StatefulWidget {
  final Map<dynamic, dynamic> eventData;

  const IncomingCallPage({Key? key, required this.eventData}) : super(key: key);

  @override
  State<IncomingCallPage> createState() => _IncomingCallPageState();
}

class _IncomingCallPageState extends State<IncomingCallPage> {
  CallKitParams? callParams;
  late String callId;
  late String callerName;
  late String phoneNumber;

  final List<String> _dummyList = [
    '서버에서 불러온 연락처 정보 1',
    '서버에서 불러온 연락처 정보 2',
    // ...
  ];

  @override
  void initState() {
    super.initState();
    _parseEventData();
  }

  void _parseEventData() {
    // event.body -> JSON -> CallKitParams
    final mapData =
        jsonDecode(jsonEncode(widget.eventData)) as Map<String, dynamic>;
    callParams = CallKitParams.fromJson(mapData);

    callId = callParams?.id ?? '';
    callerName = callParams?.nameCaller ?? 'Unknown Caller';
    phoneNumber = callParams?.handle ?? '010-0000-0000';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade200,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 40),
            Text('전화가 울립니다...', style: const TextStyle(fontSize: 24)),
            const SizedBox(height: 8),
            Text(
              callerName,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(phoneNumber, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 24),

            // 중앙 박스 (리스트)
            Expanded(
              child: Center(
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.8,
                  height: 300,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [
                      BoxShadow(color: Colors.black26, blurRadius: 5),
                    ],
                  ),
                  padding: const EdgeInsets.all(16),
                  child: ListView.separated(
                    itemCount: _dummyList.length,
                    separatorBuilder: (_, __) => const Divider(),
                    itemBuilder: (context, index) {
                      return Text(_dummyList[index]);
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // 수신
                ElevatedButton(
                  onPressed: _onAcceptCall,
                  style: ElevatedButton.styleFrom(
                    shape: const CircleBorder(),
                    padding: const EdgeInsets.all(20),
                    backgroundColor: Colors.green,
                  ),
                  child: const Icon(Icons.call, color: Colors.white),
                ),
                // 거절
                ElevatedButton(
                  onPressed: _onDeclineCall,
                  style: ElevatedButton.styleFrom(
                    shape: const CircleBorder(),
                    padding: const EdgeInsets.all(20),
                    backgroundColor: Colors.red,
                  ),
                  child: const Icon(Icons.call_end, color: Colors.white),
                ),
              ],
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Future<void> _onAcceptCall() async {
    if (callParams == null) return;

    // "수신" -> startCall with CallKitParams
    final acceptParams = CallKitParams(
      id: callId,
      nameCaller: callerName,
      handle: phoneNumber,
      type: 1, // 1: outgoing (혹은 0? 용도에 맞게)
      // 필요하다면 extra 필드나 ios/android 옵션 추가
    );

    await FlutterCallkitIncoming.startCall(acceptParams);

    // 곧바로 CallingPage로 이동
    NavigationService.instance.pushNamed(
      AppRoute.callingPage,
      args: widget.eventData, // 통화 중 화면에 넘길 데이터
    );
  }

  Future<void> _onDeclineCall() async {
    // "거절"
    await FlutterCallkitIncoming.endCall(callId);
    NavigationService.instance.goBack();
  }
}
