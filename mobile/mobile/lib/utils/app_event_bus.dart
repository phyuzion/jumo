// lib/utils/app_event_bus.dart
import 'package:event_bus/event_bus.dart';

/// 전역 EventBus 인스턴스
EventBus appEventBus = EventBus();

/// 이벤트 클래스들
class CallLogUpdatedEvent {}

class ContactsUpdatedEvent {}

class SmsUpdatedEvent {}

class NotificationCountUpdatedEvent {}

/// 통화 검색 데이터 리셋 이벤트
class CallSearchResetEvent {
  final String phoneNumber;
  CallSearchResetEvent(this.phoneNumber);
}

/// 통화 상태 변경 이벤트
class CallStateChangedEvent {
  final String state;
  final String? number;
  CallStateChangedEvent({required this.state, this.number});
}

/// 통화 상태 동기화 이벤트 (각 컴포넌트 간 상태 공유용)
class CallStateSyncEvent {
  final Map<String, dynamic> callDetails;
  final DateTime timestamp;

  CallStateSyncEvent(this.callDetails) : timestamp = DateTime.now();
}

/// 대기 통화 이벤트 (활성 통화가 있는 상태에서 새 전화 수신)
class CallWaitingEvent {
  final String activeNumber;
  final String waitingNumber;
  final DateTime timestamp;

  CallWaitingEvent({
    required this.activeNumber,
    required this.waitingNumber,
  }) : timestamp = DateTime.now();
}
