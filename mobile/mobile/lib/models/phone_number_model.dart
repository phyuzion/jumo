// lib/models/phone_number_model.dart

/// "통합 전화번호부" 한 개 문서(PhoneNumber)의 모델
///  - phoneNumber: 실제 전화번호 (string)
///  - type: 위험/분류 등(예: 0=일반, 99=위험번호)
///  - records: 이 번호에 대해 등록된 여러 레코드(누가 어떤 메모/이름/타입을 달았는지)
class PhoneNumberModel {
  final String phoneNumber;
  final int type;
  final List<PhoneRecordModel> records;

  PhoneNumberModel({
    required this.phoneNumber,
    required this.type,
    required this.records,
  });

  /// fromJson: GraphQL 응답(JSON Map)을 Model로 변환
  factory PhoneNumberModel.fromJson(Map<String, dynamic> json) {
    return PhoneNumberModel(
      phoneNumber: json['phoneNumber'] as String? ?? '',
      type: json['type'] as int? ?? 0,
      records:
          (json['records'] as List<dynamic>? ?? [])
              .map((r) => PhoneRecordModel.fromJson(r as Map<String, dynamic>))
              .toList(),
    );
  }
}

/// 한 개 레코드(누군가가 등록한 메모/이름/type 등)
class PhoneRecordModel {
  final String userName;
  final int userType;
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
      userType: json['userType'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      memo: json['memo'] as String? ?? '',
      type: json['type'] as int? ?? 0,
      createdAt: json['createdAt'] as String? ?? '',
    );
  }
}
