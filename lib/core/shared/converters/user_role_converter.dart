import 'package:json_annotation/json_annotation.dart';
import 'package:f2c/features/authentication/models/user_role.dart';

/// Custom JSON converter for UserRole enum
/// Handles conversion between Firestore's snake_case and Dart's camelCase
class UserRoleConverter implements JsonConverter<UserRole, String> {
  const UserRoleConverter();

  @override
  UserRole fromJson(String json) {
    // Convert snake_case to camelCase
    switch (json) {
      case 'super_admin':
        return UserRole.superAdmin;
      case 'admin':
        return UserRole.admin;
      case 'customer':
        return UserRole.customer;
      case 'packaging':
        return UserRole.packaging;
      case 'delivery':
        return UserRole.delivery;
      default:
        throw ArgumentError('Invalid role: $json');
    }
  }

  @override
  String toJson(UserRole role) {
    // Convert camelCase to snake_case
    switch (role) {
      case UserRole.superAdmin:
        return 'super_admin';
      case UserRole.admin:
        return 'admin';
      case UserRole.customer:
        return 'customer';
      case UserRole.packaging:
        return 'packaging';
      case UserRole.delivery:
        return 'delivery';
    }
  }
}
