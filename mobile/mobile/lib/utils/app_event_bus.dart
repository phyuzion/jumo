// lib/utils/app_event_bus.dart
import 'package:event_bus/event_bus.dart';

/// 전역 EventBus 인스턴스
EventBus appEventBus = EventBus();

/// 이벤트 클래스들
class CallLogUpdatedEvent {}

class ContactsUpdatedEvent {}

class SmsUpdatedEvent {}

class NotificationCountUpdatedEvent {}
