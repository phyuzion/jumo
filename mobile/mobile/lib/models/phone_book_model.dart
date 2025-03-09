// lib/models/phone_book_model.dart

/// 로컬 주소록 + 메모/타입/업데이트시각 등을 함께 담는 모델
class PhoneBookModel {
  /// 표시 이름 (디바이스: displayName)
  final String name;

  /// 실제 전화번호 (normalize 처리된)
  final String phoneNumber;

  /// 메모 (앱 전용)
  final String? memo;

  /// 타입 (앱 전용: 0=일반, 99=위험번호 등 임의로 사용)
  final int? type;

  /// 최종 업데이트 시각 (epoch or ISO)
  final String? updatedAt;

  PhoneBookModel({
    required this.name,
    required this.phoneNumber,
    this.memo,
    this.type,
    this.updatedAt,
  });

  /// JSON -> Model
  factory PhoneBookModel.fromJson(Map<String, dynamic> json) {
    return PhoneBookModel(
      name: json['name'] as String? ?? '',
      phoneNumber: json['phoneNumber'] as String? ?? '',
      memo: json['memo'] as String?,
      type: json['type'] as int?,
      updatedAt: json['updatedAt'] as String?,
    );
  }

  /// Model -> JSON
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'phoneNumber': phoneNumber,
      'memo': memo,
      'type': type,
      'updatedAt': updatedAt,
    };
  }

  PhoneBookModel copyWith({
    String? name,
    String? phoneNumber,
    String? memo,
    int? type,
    String? updatedAt,
  }) {
    return PhoneBookModel(
      name: name ?? this.name,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      memo: memo ?? this.memo,
      type: type ?? this.type,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
