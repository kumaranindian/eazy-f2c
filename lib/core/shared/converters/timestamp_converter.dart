import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TimestampConverter implements JsonConverter<DateTime?, Object?> {
  const TimestampConverter();

  @override
  DateTime? fromJson(Object? json) {
    if (json == null) return null;
    
    if (json is Timestamp) {
      return json.toDate();
    }
    
    if (json is String) {
      return DateTime.parse(json);
    }
    
    if (json is int) {
      return DateTime.fromMillisecondsSinceEpoch(json);
    }
    
    return null;
  }

  @override
  Object? toJson(DateTime? dateTime) {
    if (dateTime == null) return null;
    return Timestamp.fromDate(dateTime);
  }
}
