import 'package:mobile/models/today_record.dart';

class RegisteredUserInfoModel {
  final String userName;
  final String? userRegion;
  final String userType;

  RegisteredUserInfoModel({
    required this.userName,
    this.userRegion,
    required this.userType,
  });

  factory RegisteredUserInfoModel.fromJson(Map<String, dynamic> json) {
    return RegisteredUserInfoModel(
      userName: json['userName'] as String? ?? '',
      userRegion: json['userRegion'] as String?,
      userType: json['userType'] as String? ?? '일반',
    );
  }

  Map<String, dynamic> toJson() => {
    'userName': userName,
    'userRegion': userRegion,
    'userType': userType,
  };
}

class PhoneNumberModel {
  final String id;
  final String phoneNumber;
  final int type;
  final int blockCount;
  final List<PhoneRecordModel> records;
  final List<TodayRecord> todayRecords;
  final bool isRegisteredUser;
  final RegisteredUserInfoModel? registeredUserInfo;

  PhoneNumberModel({
    required this.id,
    required this.phoneNumber,
    required this.type,
    required this.blockCount,
    required this.records,
    required this.todayRecords,
    required this.isRegisteredUser,
    this.registeredUserInfo,
  });

  factory PhoneNumberModel.fromJson(Map<String, dynamic> json) {
    final recs =
        (json['records'] as List<dynamic>?)
            ?.map((e) => PhoneRecordModel.fromJson(e))
            .toList()
          ?..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final todayRecs =
        (json['todayRecords'] as List<dynamic>?)
            ?.map((e) => TodayRecord.fromJson(e))
            .toList();

    final userInfoJson = json['registeredUserInfo'];
    final RegisteredUserInfoModel? userInfo =
        userInfoJson != null
            ? RegisteredUserInfoModel.fromJson(userInfoJson)
            : null;

    return PhoneNumberModel(
      id: json['id'] as String? ?? json['phoneNumber'] as String? ?? '',
      phoneNumber: json['phoneNumber'] as String? ?? '',
      type: json['type'] as int? ?? 0,
      blockCount: json['blockCount'] as int? ?? 0,
      records: recs ?? [],
      todayRecords: todayRecs ?? [],
      isRegisteredUser: json['isRegisteredUser'] as bool? ?? false,
      registeredUserInfo: userInfo,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'phoneNumber': phoneNumber,
      'type': type,
      'blockCount': blockCount,
      'records': records.map((r) => r.toJson()).toList(),
      'todayRecords': todayRecords.map((r) => r.toJson()).toList(),
      'isRegisteredUser': isRegisteredUser,
      'registeredUserInfo': registeredUserInfo?.toJson(),
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
