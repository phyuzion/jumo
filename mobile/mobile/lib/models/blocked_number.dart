class BlockedNumber {
  final String number;

  BlockedNumber({required this.number});

  factory BlockedNumber.fromJson(Map<String, dynamic> json) {
    return BlockedNumber(number: json['number']);
  }

  Map<String, dynamic> toJson() {
    return {'number': number};
  }
}
