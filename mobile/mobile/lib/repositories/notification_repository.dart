import 'dart:convert';
import 'package:hive_ce/hive.dart';
import 'package:meta/meta.dart'; // for @visibleForTesting
import 'dart:developer';

// Hive 박스 이름 정의
const String _notificationsBoxName = 'notifications';
const String _displayNotiIdsBoxName = 'display_noti_ids';

/// 알림 데이터 및 상태 관리를 위한 추상 클래스 (인터페이스)
abstract class NotificationRepository {
  /// 저장된 모든 알림 목록을 가져옵니다.
  /// 반환값: List<Map<String, dynamic>> 형태의 알림 목록
  Future<List<Map<String, dynamic>>> getAllNotifications();

  /// 특정 ID의 알림을 가져옵니다.
  Future<Map<String, dynamic>?> getNotificationById(String id);

  /// 새로운 알림을 저장합니다.
  /// [notificationData]는 id, title, message, timestamp, validUntil 등의 키를 포함한 Map
  Future<void> saveNotification(Map<String, dynamic> notificationData);

  /// 만료된 알림을 삭제합니다.
  Future<int> removeExpiredNotifications();

  /// 특정 알림이 이미 표시되었는지 확인합니다.
  Future<bool> isNotificationDisplayed(String title, String message);

  /// 알림을 표시됨으로 표시합니다.
  Future<void> markNotificationAsDisplayed(String title, String message);

  /// 모든 알림 데이터를 삭제합니다 (로그아웃 등에서 사용).
  Future<void> clearAllNotifications();

  /// 특정 알림을 삭제합니다.
  Future<void> deleteNotificationById(String id);
}

/// Hive를 사용하여 NotificationRepository 인터페이스를 구현하는 클래스
class HiveNotificationRepository implements NotificationRepository {
  // Box 인스턴스를 저장하지 않고 필요할 때마다 여는 방식 채택 (Box 수 증가 대비)
  // 또는 생성자에서 Box 인스턴스를 받아 저장할 수도 있음 (현재 방식)
  final Box _notificationsBox;
  final Box _displayNotiIdsBox;

  HiveNotificationRepository(this._notificationsBox, this._displayNotiIdsBox);

  @override
  Future<List<Map<String, dynamic>>> getAllNotifications() async {
    try {
      // Hive 값들은 Map<dynamic, dynamic>일 수 있으므로 캐스팅 필요
      final notifications = _notificationsBox.values.toList();
      return notifications
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } catch (e) {
      log('[HiveNotificationRepository] Error getting all notifications: $e');
      return [];
    }
  }

  @override
  Future<Map<String, dynamic>?> getNotificationById(String id) async {
    try {
      final notification = _notificationsBox.get(id);
      return notification != null
          ? Map<String, dynamic>.from(notification as Map)
          : null;
    } catch (e) {
      log(
        '[HiveNotificationRepository] Error getting notification by ID ($id): $e',
      );
      return null;
    }
  }

  @override
  Future<void> saveNotification(Map<String, dynamic> notificationData) async {
    final id = notificationData['id'] as String?;
    if (id != null) {
      await _notificationsBox.put(id, notificationData);
    }
  }

  @override
  Future<int> removeExpiredNotifications() async {
    int removedCount = 0;
    final now = DateTime.now().toUtc();
    final Map<dynamic, dynamic> currentNotifications =
        _notificationsBox.toMap();

    for (var entry in currentNotifications.entries) {
      final notification = Map<String, dynamic>.from(entry.value as Map);
      final validUntilStr = notification['validUntil'] as String?;
      if (validUntilStr != null) {
        try {
          final validUntil = DateTime.parse(validUntilStr).toUtc();
          if (validUntil.isBefore(now)) {
            await _notificationsBox.delete(entry.key);
            removedCount++;
          }
        } catch (e) {
          log(
            '[HiveNotificationRepository] Error parsing validUntil ($validUntilStr): $e',
          );
          // 날짜 파싱 오류 시 삭제하지 않음
        }
      }
    }
    if (removedCount > 0) {
      log(
        '[HiveNotificationRepository] Removed $removedCount expired notifications.',
      );
    }
    return removedCount;
  }

  @override
  Future<bool> isNotificationDisplayed(String title, String message) async {
    final displayedList = await _getDisplayedNotificationsList();
    return displayedList.any(
      (noti) => noti['title'] == title && noti['message'] == message,
    );
  }

  @override
  Future<void> markNotificationAsDisplayed(String title, String message) async {
    final displayedList = await _getDisplayedNotificationsList();
    // 중복 추가 방지
    if (!displayedList.any(
      (noti) => noti['title'] == title && noti['message'] == message,
    )) {
      displayedList.add({'title': title, 'message': message});
      await _saveDisplayedNotificationsList(displayedList);
    }
  }

  @override
  Future<void> clearAllNotifications() async {
    await _notificationsBox.clear();
    await _displayNotiIdsBox.clear(); // 표시된 ID 목록도 클리어
  }

  @override
  Future<void> deleteNotificationById(String id) async {
    await _notificationsBox.delete(id);
    // 필요하다면 displayed list에서도 관련 항목 제거 로직 추가
  }

  // --- Helper methods for displayed notifications list ---
  Future<List<Map<String, dynamic>>> _getDisplayedNotificationsList() async {
    final displayedListRaw =
        _displayNotiIdsBox.get('ids', defaultValue: '[]') as String;
    try {
      return (jsonDecode(displayedListRaw) as List)
          .cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveDisplayedNotificationsList(
    List<Map<String, dynamic>> list,
  ) async {
    await _displayNotiIdsBox.put('ids', jsonEncode(list));
  }
}
