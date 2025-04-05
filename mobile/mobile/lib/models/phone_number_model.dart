class PhoneNumberModel {
  final String phoneNumber;
  final int type;
  final List<PhoneRecordModel> records;

  PhoneNumberModel({
    required this.phoneNumber,
    required this.type,
    required this.records,
  });

  // fromJson, toJson
  factory PhoneNumberModel.fromJson(Map<String, dynamic> json) {
    final recs =
        (json['records'] as List<dynamic>?)
            ?.map((e) => PhoneRecordModel.fromJson(e))
            .toList()
          ?..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return PhoneNumberModel(
      phoneNumber: json['phoneNumber'] as String,
      type: json['type'] as int,
      records: recs ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'phoneNumber': phoneNumber,
      'type': type,
      'records': records.map((r) => r.toJson()).toList(),
    };
  }
}

class PhoneRecordModel {
  final String userName;
  final String userType;
  final String name;
  final String memo;
  final int type;
  final String createdAt;

  PhoneRecordModel({
    required this.userName,
    required this.userType,
    required this.name,
    required this.memo,
    required this.type,
    required this.createdAt,
  });

  factory PhoneRecordModel.fromJson(Map<String, dynamic> json) {
    return PhoneRecordModel(
      userName: json['userName'] as String? ?? '',
      userType: json['userType'] as String? ?? '일반',
      name: json['name'] as String? ?? '',
      memo: json['memo'] as String? ?? '',
      type: json['type'] as int? ?? 0,
      createdAt: json['createdAt'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userName': userName,
      'userType': userType,
      'name': name,
      'memo': memo,
      'type': type,
      'createdAt': createdAt,
    };
  }
}
