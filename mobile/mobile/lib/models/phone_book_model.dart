// lib/models/phone_book_model.dart

/// 로컬 DB에 저장되는 주소록 모델
/// - 디바이스 연락처의 contactId (flutter_contacts의 Contact.id)
/// - 이름, 전화번호
/// - 메모, 타입 (앱에서만 사용)
/// - updatedAt (diff 여부 판단)
class PhoneBookModel {
  /// flutter_contacts 의 Contact.id (Android에서 rawId 처리 포함)
  final String contactId;

  /// Android RawContacts._ID (raw_contact_id)
  final String? rawContactId;

  /// 표시 이름
  final String name;

  /// 실제 전화번호 (normalize 처리된)
  final String phoneNumber;

  /// 메모 (앱 전용)
  final String? memo;

  /// 타입 (앱 전용: 0=일반, 99=위험번호 등)
  final int? type;

  /// 최종 업데이트 시각 (ISO 형식 등)
  final String? updatedAt;

  /// 생성 시각
  final DateTime? createdAt;

  PhoneBookModel({
    required this.contactId,
    required this.name,
    required this.phoneNumber,
    this.memo,
    this.type,
    this.updatedAt,
    this.rawContactId,
    this.createdAt,
  });

  factory PhoneBookModel.fromJson(Map<String, dynamic> json) {
    return PhoneBookModel(
      contactId: json['contactId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      phoneNumber: json['phoneNumber'] as String? ?? '',
      memo: json['memo'] as String?,
      type: json['type'] as int?,
      updatedAt: json['updatedAt'] as String?,
      rawContactId: json['rawContactId'] as String?,
      createdAt:
          (() {
            final v = json['createdAt'];
            if (v == null) return null;
            if (v is DateTime) return v;
            if (v is int)
              return DateTime.fromMillisecondsSinceEpoch(v, isUtc: true);
            if (v is String) return DateTime.tryParse(v);
            return null;
          })(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'contactId': contactId,
      'name': name,
      'phoneNumber': phoneNumber,
      'memo': memo,
      'type': type,
      'updatedAt': updatedAt,
      'rawContactId': rawContactId,
      'createdAt': createdAt?.millisecondsSinceEpoch,
    };
  }

  PhoneBookModel copyWith({
    String? contactId,
    String? name,
    String? phoneNumber,
    String? memo,
    int? type,
    String? updatedAt,
    String? rawContactId,
    DateTime? createdAt,
  }) {
    return PhoneBookModel(
      contactId: contactId ?? this.contactId,
      name: name ?? this.name,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      memo: memo ?? this.memo,
      type: type ?? this.type,
      updatedAt: updatedAt ?? this.updatedAt,
      rawContactId: rawContactId ?? this.rawContactId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory PhoneBookModel.fromMap(Map<String, dynamic> map) {
    return PhoneBookModel(
      contactId: map['id']?.toString() ?? '',
      rawContactId: map['rawId']?.toString(),
      name: map['displayName']?.toString() ?? '',
      phoneNumber: map['phoneNumber']?.toString() ?? '',
      createdAt:
          (() {
            final v = map['lastUpdated'];
            if (v == null) return null;
            if (v is DateTime) return v;
            if (v is int) {
              return DateTime.fromMillisecondsSinceEpoch(v, isUtc: true);
            }
            if (v is String) return DateTime.tryParse(v);
            return null;
          })(),
    );
  }
}
