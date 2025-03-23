class BlockedHistory {
  final String phoneNumber;
  final DateTime blockedAt;
  final String type;

  BlockedHistory({
    required this.phoneNumber,
    required this.blockedAt,
    required this.type,
  });

  Map<String, dynamic> toJson() {
    return {
      'phoneNumber': phoneNumber,
      'blockedAt': blockedAt.toIso8601String(),
      'type': type,
    };
  }

  factory BlockedHistory.fromJson(Map<String, dynamic> json) {
    return BlockedHistory(
      phoneNumber: json['phoneNumber'],
      blockedAt: DateTime.parse(json['blockedAt']),
      type: json['type'],
    );
  }
}
