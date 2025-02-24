// lib/core/services/callkit_service.dart

import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_callkit_incoming/entities/call_event.dart';
import 'package:flutter_callkit_incoming/entities/call_kit_params.dart';

class CallKitService {
  /// 이벤트 스트림 getter
  static Stream<CallEvent?> get onEvent => FlutterCallkitIncoming.onEvent;

  /// 인커밍 콜 표시
  static Future<void> showIncomingCall(CallKitParams params) async {
    await FlutterCallkitIncoming.showCallkitIncoming(params);
  }

  /// 통화 종료
  static Future<void> endCall(String callId) async {
    await FlutterCallkitIncoming.endCall(callId);
  }

  /// 통화 시작(OutGoing)
  static Future<void> startCall(CallKitParams params) async {
    await FlutterCallkitIncoming.startCall(params);
  }

  /// (etc) setCallConnected, endAllCalls 등 필요한 메서드 자유롭게
}
