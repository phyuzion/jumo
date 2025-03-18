class BlockedNumber {
  final String number;
  final DateTime blockedAt;

  BlockedNumber({required this.number, required this.blockedAt});

  Map<String, dynamic> toJson() {
    return {'number': number, 'blockedAt': blockedAt.toIso8601String()};
  }

  factory BlockedNumber.fromJson(Map<String, dynamic> json) {
    return BlockedNumber(
      number: json['number'],
      blockedAt: DateTime.parse(json['blockedAt']),
    );
  }
}
