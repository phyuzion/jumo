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

  /// 서버에 존재하는 알림 ID 목록과 로컬 알림을 동기화합니다.
  /// 서버에 없는 알림은 로컬에서 삭제합니다.
  /// [serverIds]: 서버에 존재하는 알림 ID 목록
  /// 반환값: 삭제된 알림 수
  Future<int> syncWithServerIds(List<String> serverIds);
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
      // 저장 전 데이터 상세 로깅
      final validUntil = notificationData['validUntil'];
      final validUntilType = validUntil?.runtimeType.toString() ?? 'null';
      log(
        '[HiveNotificationRepository] SAVING NOTIFICATION - id: $id, validUntil: $validUntil, type: $validUntilType',
      );

      // validUntil 값을 정수로 통일
      var updatedData = Map<String, dynamic>.from(notificationData);
      if (validUntil != null) {
        if (validUntil is String && RegExp(r'^\d+$').hasMatch(validUntil)) {
          // 숫자 문자열이면 정수로 변환
          updatedData['validUntil'] = int.parse(validUntil);
          log(
            '[HiveNotificationRepository] Converting String validUntil to int: $validUntil → ${updatedData['validUntil']}',
          );
        } else if (validUntil is String) {
          // ISO 문자열 형식이면 타임스탬프로 변환
          try {
            final dt = DateTime.parse(validUntil);
            updatedData['validUntil'] = dt.millisecondsSinceEpoch;
            log(
              '[HiveNotificationRepository] Converting ISO String validUntil to timestamp: $validUntil → ${updatedData['validUntil']}',
            );
          } catch (e) {
            log(
              '[HiveNotificationRepository] Unable to parse String validUntil: $validUntil, error: $e',
            );
          }
        }
      }

      // 저장
      await _notificationsBox.put(id, updatedData);

      // 저장 후 바로 확인을 위해 다시 읽어오기
      final savedData = _notificationsBox.get(id);
      final savedValidUntil = savedData?['validUntil'];
      final savedValidUntilType =
          savedValidUntil?.runtimeType.toString() ?? 'null';
      log(
        '[HiveNotificationRepository] AFTER SAVE CHECK - id: $id, validUntil: $savedValidUntil, type: $savedValidUntilType',
      );
    }
  }

  @override
  Future<int> removeExpiredNotifications() async {
    int removedCount = 0;
    // 현재 시간을 UTC로 가져옴
    final now = DateTime.now().toUtc();
    final Map<dynamic, dynamic> currentNotifications =
        _notificationsBox.toMap();

    // 전체 알림 목록 로깅
    log('[HiveNotificationRepository] ===== CHECKING ALL NOTIFICATIONS =====');
    log(
      '[HiveNotificationRepository] Total notifications: ${currentNotifications.length}',
    );

    for (var entry in currentNotifications.entries) {
      final key = entry.key;
      final notification = Map<String, dynamic>.from(entry.value as Map);
      final id = notification['id'] as String?;
      final title = notification['title'] as String?;
      final validUntilValue = notification['validUntil'];
      final validUntilType = validUntilValue?.runtimeType.toString() ?? 'null';

      log(
        '[HiveNotificationRepository] CHECKING NOTIFICATION - key: $key, id: $id, title: $title, validUntil: $validUntilValue, type: $validUntilType',
      );

      // 알림 데이터 전체 로깅
      log('[HiveNotificationRepository] FULL DATA: ${notification.toString()}');

      if (validUntilValue == null) {
        log(
          '[HiveNotificationRepository] Skipping notification with null validUntil',
        );
        continue;
      }

      try {
        DateTime validUntilUtc;

        if (validUntilValue is String) {
          // 문자열이 숫자 형식인지 확인
          if (RegExp(r'^\d+$').hasMatch(validUntilValue)) {
            // 숫자 문자열인 경우 (밀리초 타임스탬프) - int로 변환 후 처리
            final intValue = int.parse(validUntilValue);
            validUntilUtc = DateTime.fromMillisecondsSinceEpoch(
              intValue,
              isUtc: true,
            );
            log(
              '[HiveNotificationRepository] Parsed numeric String timestamp: $validUntilValue → UTC: ${validUntilUtc.toIso8601String()}, KST: ${validUntilUtc.toLocal().toString()}',
            );
          } else {
            // ISO 문자열 형식 처리 ("2023-01-01T00:00:00.000Z")
            validUntilUtc = DateTime.parse(validUntilValue).toUtc();
            log(
              '[HiveNotificationRepository] Parsed ISO String timestamp: $validUntilValue → UTC: ${validUntilUtc.toIso8601String()}, KST: ${validUntilUtc.toLocal().toString()}',
            );
          }
        } else if (validUntilValue is int) {
          // 2. 밀리초 타임스탬프 처리 (1749206400000)
          // UTC 타임스탬프로 간주하고 파싱
          validUntilUtc = DateTime.fromMillisecondsSinceEpoch(
            validUntilValue,
            isUtc: true,
          );
          log(
            '[HiveNotificationRepository] Parsed Integer timestamp: $validUntilValue → UTC: ${validUntilUtc.toIso8601String()}, KST: ${validUntilUtc.toLocal().toString()}',
          );
        } else if (validUntilValue is double) {
          // 3. 숫자 형식이지만 double로 파싱된 경우
          validUntilUtc = DateTime.fromMillisecondsSinceEpoch(
            validUntilValue.toInt(),
            isUtc: true,
          );
          log(
            '[HiveNotificationRepository] Parsed Double timestamp: $validUntilValue → UTC: ${validUntilUtc.toIso8601String()}, KST: ${validUntilUtc.toLocal().toString()}',
          );
        } else {
          // 4. 알 수 없는 형식은 로그만 남기고 계속 진행
          log(
            '[HiveNotificationRepository] Unknown validUntil format: ${validUntilValue.runtimeType} - $validUntilValue',
          );
          continue;
        }

        // UTC 기준으로 비교 (now도 UTC)
        if (validUntilUtc.isBefore(now)) {
          await _notificationsBox.delete(entry.key);
          removedCount++;
          log(
            '[HiveNotificationRepository] REMOVED expired notification with validUntil=${validUntilUtc.toIso8601String()}, now=${now.toIso8601String()}',
          );
        } else {
          // 만료되지 않은 경우 남은 시간 로깅 (디버그용)
          final remaining = validUntilUtc.difference(now).inHours;
          log(
            '[HiveNotificationRepository] Notification still valid: ${remaining}h remaining. validUntil=${validUntilUtc.toIso8601String()}, KST=${validUntilUtc.toLocal().toString()}',
          );
        }
      } catch (e, stackTrace) {
        log(
          '[HiveNotificationRepository] Error parsing validUntil ($validUntilValue): $e',
        );
        log('[HiveNotificationRepository] Stack trace: $stackTrace');

        // 값의 상세 정보 출력
        if (validUntilValue is String) {
          log(
            '[HiveNotificationRepository] String value length: ${validUntilValue.length}, value: $validUntilValue',
          );
          // String을 int로 변환 시도
          try {
            final intValue = int.parse(validUntilValue);
            final dateFromInt = DateTime.fromMillisecondsSinceEpoch(
              intValue,
              isUtc: true,
            );
            log(
              '[HiveNotificationRepository] String→Int conversion test: $intValue → ${dateFromInt.toIso8601String()}',
            );
          } catch (e) {
            log(
              '[HiveNotificationRepository] String→Int conversion failed: $e',
            );
          }
        }

        // 날짜 파싱 오류 시 삭제하지 않음
      }
    }

    // 검사 완료 로깅
    log('[HiveNotificationRepository] ===== CHECKING COMPLETED =====');

    if (removedCount > 0) {
      log(
        '[HiveNotificationRepository] Removed $removedCount expired notifications.',
      );
    } else {
      log('[HiveNotificationRepository] No expired notifications found.');
    }

    // 변경 후 남은 알림 확인
    final remainingNotifications = _notificationsBox.toMap();
    log(
      '[HiveNotificationRepository] Remaining notifications: ${remainingNotifications.length}',
    );

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

  @override
  Future<int> syncWithServerIds(List<String> serverIds) async {
    try {
      log(
        '[HiveNotificationRepository] Syncing notifications with server IDs...',
      );
      log(
        '[HiveNotificationRepository] Server IDs count: ${serverIds.length}, IDs: $serverIds',
      );

      final localIds = _notificationsBox.keys.map((k) => k.toString()).toList();
      log(
        '[HiveNotificationRepository] Local IDs count: ${localIds.length}, IDs: $localIds',
      );

      final idsToDelete = <String>[];
      for (final localId in localIds) {
        if (!serverIds.contains(localId)) {
          idsToDelete.add(localId);
        }
      }

      log(
        '[HiveNotificationRepository] IDs to delete count: ${idsToDelete.length}, IDs: $idsToDelete',
      );

      for (final id in idsToDelete) {
        await _notificationsBox.delete(id);
      }

      log(
        '[HiveNotificationRepository] Deleted ${idsToDelete.length} notifications that no longer exist on server',
      );
      return idsToDelete.length;
    } catch (e) {
      log('[HiveNotificationRepository] Error syncing with server IDs: $e');
      return 0;
    }
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
