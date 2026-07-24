import 'package:freezed_annotation/freezed_annotation.dart';

part 'audit_log_model.freezed.dart';
part 'audit_log_model.g.dart';

enum AuditAction {
  login,
  logout,
  passwordChanged,
  passwordReset,
  userCreated,
  userUpdated,
  userDeleted,
  userActivated,
  userDeactivated,
  roleChanged,
  branchAssigned,
  hubAssigned,
  profileUpdated,
  sessionExpired,
  loginFailed,
  accountLocked,
  accountUnlocked;

  String get displayName {
    switch (this) {
      case AuditAction.login:
        return 'Login';
      case AuditAction.logout:
        return 'Logout';
      case AuditAction.passwordChanged:
        return 'Password Changed';
      case AuditAction.passwordReset:
        return 'Password Reset';
      case AuditAction.userCreated:
        return 'User Created';
      case AuditAction.userUpdated:
        return 'User Updated';
      case AuditAction.userDeleted:
        return 'User Deleted';
      case AuditAction.userActivated:
        return 'User Activated';
      case AuditAction.userDeactivated:
        return 'User Deactivated';
      case AuditAction.roleChanged:
        return 'Role Changed';
      case AuditAction.branchAssigned:
        return 'Branch Assigned';
      case AuditAction.hubAssigned:
        return 'Hub Assigned';
      case AuditAction.profileUpdated:
        return 'Profile Updated';
      case AuditAction.sessionExpired:
        return 'Session Expired';
      case AuditAction.loginFailed:
        return 'Login Failed';
      case AuditAction.accountLocked:
        return 'Account Locked';
      case AuditAction.accountUnlocked:
        return 'Account Unlocked';
    }
  }
}

@freezed
class AuditLogModel with _$AuditLogModel {
  const factory AuditLogModel({
    required String id,
    required AuditAction action,
    required String performedBy,
    String? performedFor,
    required DateTime timestamp,
    String? device,
    String? ipAddress,
    required String environment,
    Map<String, dynamic>? metadata,
    String? description,
  }) = _AuditLogModel;

  factory AuditLogModel.fromJson(Map<String, dynamic> json) =>
      _$AuditLogModelFromJson(json);

  const AuditLogModel._();

  String get actionDisplay => action.displayName;
}
