import 'package:mobile/models/phone_number_model.dart';
import 'package:mobile/models/today_record.dart';

class SearchResultModel {
  final PhoneNumberModel? phoneNumberModel;
  final List<TodayRecord>? todayRecords;

  SearchResultModel({this.phoneNumberModel, this.todayRecords});

  Map<String, dynamic> toJson() {
    return {
      'phoneNumberModel': phoneNumberModel?.toJson(),
      'todayRecords': todayRecords?.map((e) => e.toJson()).toList(),
    };
  }

  factory SearchResultModel.fromJson(Map<String, dynamic> json) {
    return SearchResultModel(
      phoneNumberModel:
          json['phoneNumberModel'] != null
              ? PhoneNumberModel.fromJson(json['phoneNumberModel'])
              : null,
      todayRecords:
          (json['todayRecords'] as List<dynamic>?)
              ?.map((e) => TodayRecord.fromJson(e))
              .toList(),
    );
  }
}
