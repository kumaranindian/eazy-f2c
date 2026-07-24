import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:f2c/features/authentication/models/user_role.dart';

part 'session_model.freezed.dart';
part 'session_model.g.dart';

@freezed
class SessionModel with _$SessionModel {
  const factory SessionModel({
    required String uid,
    required String username,
    required UserRole role,
    String? branchId,
    String? hubId,
    required DateTime loginTime,
    required String token,
    @Default(false) bool rememberMe,
  }) = _SessionModel;

  factory SessionModel.fromJson(Map<String, dynamic> json) =>
      _$SessionModelFromJson(json);

  const SessionModel._();

  bool isExpired(int sessionTimeoutMinutes) {
    final now = DateTime.now();
    final difference = now.difference(loginTime);
    return difference.inMinutes >= sessionTimeoutMinutes;
  }

  bool needsTokenRefresh(int tokenRefreshMinutes) {
    final now = DateTime.now();
    final difference = now.difference(loginTime);
    return difference.inMinutes >= tokenRefreshMinutes;
  }

  SessionModel copyWithNewToken(String newToken) {
    return copyWith(
      token: newToken,
      loginTime: DateTime.now(),
    );
  }
}
