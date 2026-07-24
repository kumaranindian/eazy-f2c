import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:f2c/features/authentication/models/user_role.dart';
import 'package:f2c/core/shared/converters/timestamp_converter.dart';

part 'user_model.freezed.dart';
part 'user_model.g.dart';

@Freezed(toJson: true)
@JsonSerializable(explicitToJson: true)
class UserModel with _$UserModel {
  const factory UserModel({
    required String id,
    required String name,
    required String username,
    required String email,
    required String mobile,
    String? alternativeMobile,
    required UserRole role,
    String? branchId,
    String? hubId,
    String? profileImage,
    @Default(true) bool isActive,
    @Default(false) bool isDeleted,
    @Default(false) bool passwordChanged,
    @TimestampConverter() DateTime? lastLogin,
    @TimestampConverter() required DateTime createdAt,
    @TimestampConverter() required DateTime updatedAt,
    required String createdBy,
    required String updatedBy,
  }) = _UserModel;

  factory UserModel.fromJson(Map<String, dynamic> json) {
    // Convert Firestore Timestamps to DateTime before deserialization
    final convertedJson = Map<String, dynamic>.from(json);
    
    if (convertedJson['createdAt'] is Timestamp) {
      convertedJson['createdAt'] = (convertedJson['createdAt'] as Timestamp).toDate().toIso8601String();
    }
    
    if (convertedJson['updatedAt'] is Timestamp) {
      convertedJson['updatedAt'] = (convertedJson['updatedAt'] as Timestamp).toDate().toIso8601String();
    }
    
    if (convertedJson['lastLogin'] is Timestamp) {
      convertedJson['lastLogin'] = (convertedJson['lastLogin'] as Timestamp).toDate().toIso8601String();
    }
    
    // Convert legacy super_admin to superAdmin for backward compatibility
    if (convertedJson['role'] == 'super_admin') {
      convertedJson['role'] = 'superAdmin';
    }
    
    return _$UserModelFromJson(convertedJson);
  }

  const UserModel._();

  bool get canLogin => isActive && !isDeleted;

  bool get requiresPasswordChange => !passwordChanged;

  String get displayRole => role.displayName;

  String get initials {
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.substring(0, 2).toUpperCase();
  }

  String get avatarUrl {
    if (profileImage != null && profileImage!.isNotEmpty) {
      return profileImage!;
    }
    return 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(name)}&background=random';
  }
}
