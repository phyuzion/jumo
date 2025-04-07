import 'package:hive_ce/hive.dart';

part 'blocked_history.g.dart';

@HiveType(typeId: 0)
class BlockedHistory extends HiveObject {
  @HiveField(0)
  final String phoneNumber;

  @HiveField(1)
  final DateTime blockedAt;

  @HiveField(2)
  final String type;

  BlockedHistory({
    required this.phoneNumber,
    required this.blockedAt,
    required this.type,
  });

  factory BlockedHistory.fromJson(Map<String, dynamic> json) {
    return BlockedHistory(
      phoneNumber: json['phoneNumber'] as String? ?? '',
      blockedAt: DateTime.parse(
        json['blockedAt'] as String? ?? DateTime.now().toIso8601String(),
      ),
      type: json['type'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'phoneNumber': phoneNumber,
      'blockedAt': blockedAt.toIso8601String(),
      'type': type,
    };
  }
}
