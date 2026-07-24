import 'package:freezed_annotation/freezed_annotation.dart';

part 'app_exception.freezed.dart';

@freezed
class AppException with _$AppException implements Exception {
  const factory AppException.network({
    required String message,
    String? code,
    dynamic originalError,
  }) = NetworkException;

  const factory AppException.authentication({
    required String message,
    String? code,
    dynamic originalError,
  }) = AuthenticationException;

  const factory AppException.authorization({
    required String message,
    String? code,
    dynamic originalError,
  }) = AuthorizationException;

  const factory AppException.validation({
    required String message,
    Map<String, String>? fieldErrors,
  }) = ValidationException;

  const factory AppException.notFound({
    required String message,
    String? resource,
  }) = NotFoundException;

  const factory AppException.server({
    required String message,
    String? code,
    dynamic originalError,
  }) = ServerException;

  const factory AppException.unknown({
    required String message,
    dynamic originalError,
  }) = UnknownException;

  const factory AppException.userInactive({
    required String message,
  }) = UserInactiveException;

  const factory AppException.userDeleted({
    required String message,
  }) = UserDeletedException;

  const factory AppException.passwordChangeRequired({
    required String message,
  }) = PasswordChangeRequiredException;
}
