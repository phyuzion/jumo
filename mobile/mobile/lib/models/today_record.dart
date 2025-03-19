class TodayRecord {
  final String id;
  final String phoneNumber;
  final String userName;
  final int userType;
  final String callType;
  final String createdAt;

  TodayRecord({
    required this.id,
    required this.phoneNumber,
    required this.userName,
    required this.userType,
    required this.callType,
    required this.createdAt,
  });

  factory TodayRecord.fromJson(Map<String, dynamic> json) {
    return TodayRecord(
      id: json['id'] as String,
      phoneNumber: json['phoneNumber'] as String,
      userName: json['userName'] as String,
      userType: json['userType'] as int,
      callType: json['callType'] as String,
      createdAt: json['createdAt'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'phoneNumber': phoneNumber,
      'userName': userName,
      'userType': userType,
      'callType': callType,
      'createdAt': createdAt,
    };
  }
}
