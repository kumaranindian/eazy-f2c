import 'package:f2c/core/exceptions/app_exception.dart';
import 'package:f2c/core/shared/logger/app_logger.dart';
import 'package:f2c/features/authentication/datasources/auth_remote_datasource.dart';
import 'package:f2c/features/authentication/datasources/session_local_datasource.dart';
import 'package:f2c/features/authentication/datasources/audit_log_datasource.dart';
import 'package:f2c/features/authentication/models/audit_log_model.dart';
import 'package:f2c/features/authentication/models/login_request.dart';
import 'package:f2c/features/authentication/models/session_model.dart';
import 'package:f2c/features/authentication/models/user_model.dart';

abstract class AuthRepository {
  Future<UserModel> login(LoginRequest request);
  Future<void> logout();
  Future<void> changePassword(String currentPassword, String newPassword);
  Future<SessionModel?> getCurrentSession();
  Future<bool> hasActiveSession();
  Future<void> refreshToken();
}

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required AuthRemoteDataSource remoteDataSource,
    required SessionLocalDataSource localDataSource,
    required AuditLogDataSource auditLogDataSource,
  })  : _remoteDataSource = remoteDataSource,
        _localDataSource = localDataSource,
        _auditLogDataSource = auditLogDataSource;

  final AuthRemoteDataSource _remoteDataSource;
  final SessionLocalDataSource _localDataSource;
  final AuditLogDataSource _auditLogDataSource;

  @override
  Future<UserModel> login(LoginRequest request) async {
    try {
      AppLogger.info('Login attempt for: ${request.username}');

      final user = await _remoteDataSource.loginWithUsername(
        request.username,
        request.password,
      );

      final token = await _remoteDataSource.getIdToken();
      if (token == null) {
        throw const AppException.authentication(
          message: 'Failed to get authentication token',
        );
      }

      final session = SessionModel(
        uid: user.id,
        username: user.username,
        role: user.role,
        branchId: user.branchId,
        hubId: user.hubId,
        loginTime: DateTime.now(),
        token: token,
        rememberMe: request.rememberMe,
      );

      await _localDataSource.saveSession(session);

      if (request.rememberMe) {
        await _localDataSource.saveLastUsername(request.username);
      } else {
        await _localDataSource.clearLastUsername();
      }

      try {
        await _auditLogDataSource.logAction(
          action: AuditAction.login,
          performedBy: user.id,
          description: 'User logged in successfully',
        );
      } catch (e) {
        AppLogger.error('Failed to create audit log for login', e);
      }

      AppLogger.info('Login successful for: ${user.username}');

      return user;
    } on AppException {
      try {
        await _auditLogDataSource.logAction(
          action: AuditAction.loginFailed,
          performedBy: 'system',
          description: 'Failed login attempt for username: ${request.username}',
        );
      } catch (e) {
        AppLogger.error('Failed to create audit log for login failure', e);
      }
      rethrow;
    } catch (e, stackTrace) {
      AppLogger.error('Login error', e, stackTrace);
      try {
        await _auditLogDataSource.logAction(
          action: AuditAction.loginFailed,
          performedBy: 'system',
          description: 'Failed login attempt for username: ${request.username}',
        );
      } catch (auditError) {
        AppLogger.error('Failed to create audit log for login failure', auditError);
      }
      throw AppException.unknown(
        message: 'Login failed',
        originalError: e,
      );
    }
  }

  @override
  Future<void> logout() async {
    try {
      final session = await _localDataSource.getSession();
      
      await _remoteDataSource.logout();
      await _localDataSource.clearSession();

      if (session != null) {
        try {
          await _auditLogDataSource.logAction(
            action: AuditAction.logout,
            performedBy: session.uid,
            description: 'User logged out',
          );
        } catch (e) {
          AppLogger.error('Failed to create audit log for logout', e);
        }
      }

      AppLogger.info('Logout successful');
    } catch (e, stackTrace) {
      AppLogger.error('Logout error', e, stackTrace);
      throw AppException.unknown(
        message: 'Logout failed',
        originalError: e,
      );
    }
  }

  @override
  Future<void> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    try {
      final session = await _localDataSource.getSession();
      if (session == null) {
        throw const AppException.authentication(
          message: 'No active session',
        );
      }

      await _remoteDataSource.changePassword(currentPassword, newPassword);

      try {
        await _auditLogDataSource.logAction(
          action: AuditAction.passwordChanged,
          performedBy: session.uid,
          description: 'User changed password',
        );
      } catch (e) {
        AppLogger.error('Failed to create audit log for password change', e);
      }

      AppLogger.info('Password changed successfully');
    } catch (e, stackTrace) {
      AppLogger.error('Change password error', e, stackTrace);
      if (e is AppException) rethrow;
      throw AppException.unknown(
        message: 'Failed to change password',
        originalError: e,
      );
    }
  }

  @override
  Future<SessionModel?> getCurrentSession() async {
    return await _localDataSource.getSession();
  }

  @override
  Future<bool> hasActiveSession() async {
    return await _localDataSource.hasActiveSession();
  }

  @override
  Future<void> refreshToken() async {
    try {
      await _remoteDataSource.refreshToken();
      
      final session = await _localDataSource.getSession();
      if (session != null) {
        final newToken = await _remoteDataSource.getIdToken();
        if (newToken != null) {
          final updatedSession = session.copyWithNewToken(newToken);
          await _localDataSource.saveSession(updatedSession);
        }
      }

      AppLogger.debug('Token refreshed successfully');
    } catch (e, stackTrace) {
      AppLogger.error('Token refresh error', e, stackTrace);
    }
  }
}
