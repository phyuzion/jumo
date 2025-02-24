// lib/core/controllers/phone_controller.dart

import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import '../../navigation/app_router.dart';
import '../../navigation/navigation_service.dart';

class PhoneController {
  PhoneController._internal();
  static final PhoneController _instance = PhoneController._internal();
  factory PhoneController() => _instance;

  bool _isInitialized = false;

  void initPhoneLogic() {
    if (_isInitialized) return;
    _isInitialized = true;

    // Listen to callkit incoming events
    FlutterCallkitIncoming.onEvent.listen((CallEvent? event) {
      if (event == null) return;
      switch (event.event) {
        case Event.actionCallIncoming:
          // 전화 울리는 중
          _showIncomingCallPage(event.body);
          break;
        // OS 알림에서 "Accept" 누른 경우
        case Event.actionCallAccept:
          // 만약 OS 알림으로 직접 Accept 시
          // "IncomingCallPage"를 거치지 않고 바로 "CallingPage"로 넘어가고 싶으면:
          // _goCallingPage(event.body);
          break;

        case Event.actionCallDecline:
          break;
        case Event.actionCallEnded:
          break;
        default:
          break;
      }
    });
  }

  void _showIncomingCallPage(Map<String, dynamic>? data) {
    if (data == null) return;
    NavigationService.instance.pushNamedIfNotCurrent(
      AppRoute.incomingCallPage,
      args: data,
    );
  }

  // OS 알림으로 Accept 시, 바로 통화중 페이지를 띄우고 싶으면 사용
  // void _goCallingPage(Map<String, dynamic> data) {
  //   NavigationService.instance.pushNamedIfNotCurrent(
  //     AppRoute.callingPage,
  //     args: data,
  //   );
  // }
}
