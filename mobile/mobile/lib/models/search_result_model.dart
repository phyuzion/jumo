import 'package:mobile/models/phone_number_model.dart';
import 'package:mobile/models/today_record.dart';

class SearchResultModel {
  final PhoneNumberModel? phoneNumberModel;
  final List<TodayRecord>? todayRecords;
  final bool isNew;

  SearchResultModel({
    this.phoneNumberModel,
    this.todayRecords,
    this.isNew = false,
  });

  Map<String, dynamic> toJson() {
    if (isNew) {
      return {
        'isNew': true,
        'phoneNumber': phoneNumberModel?.phoneNumber ?? '',
      };
    }

    return {
      'isNew': false,
      'phoneNumber': phoneNumberModel?.phoneNumber ?? '',
      'phoneNumberData': phoneNumberModel?.toJson(),
      'todayRecords': todayRecords?.map((r) => r.toJson()).toList(),
    };
  }

  factory SearchResultModel.fromJson(Map<String, dynamic> json) {
    if (json['isNew'] == true) {
      return SearchResultModel(
        isNew: true,
        phoneNumberModel: PhoneNumberModel(
          phoneNumber: json['phoneNumber'],
          type: 0,
          records: [],
        ),
      );
    }

    return SearchResultModel(
      isNew: false,
      phoneNumberModel:
          json['phoneNumberData'] != null
              ? PhoneNumberModel.fromJson(json['phoneNumberData'])
              : null,
      todayRecords:
          json['todayRecords'] != null
              ? (json['todayRecords'] as List)
                  .map((r) => TodayRecord.fromJson(r))
                  .toList()
              : null,
    );
  }
}
