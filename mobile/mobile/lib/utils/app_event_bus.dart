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
