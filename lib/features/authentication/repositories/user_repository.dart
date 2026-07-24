import 'package:f2c/core/exceptions/app_exception.dart';
import 'package:f2c/core/shared/logger/app_logger.dart';
import 'package:f2c/features/authentication/datasources/user_remote_datasource.dart';
import 'package:f2c/features/authentication/datasources/audit_log_datasource.dart';
import 'package:f2c/features/authentication/models/audit_log_model.dart';
import 'package:f2c/features/authentication/models/user_model.dart';
import 'package:f2c/features/authentication/models/user_role.dart';

abstract class UserRepository {
  Future<UserModel> getUserById(String userId);
  Future<UserModel> getUserByUsername(String username);
  Future<List<UserModel>> getAllUsers();
  Future<List<UserModel>> getUsersByRole(UserRole role);
  Future<UserModel> createUser(UserModel user, String password, String performedBy);
  Future<UserModel> updateUser(UserModel user, String performedBy);
  Future<void> deleteUser(String userId, String performedBy);
  Future<void> activateUser(String userId, String performedBy);
  Future<void> deactivateUser(String userId, String performedBy);
  Future<String> resetPassword(String userId, String performedBy);
  Future<bool> isUsernameAvailable(String username);
}

class UserRepositoryImpl implements UserRepository {
  UserRepositoryImpl({
    required UserRemoteDataSource remoteDataSource,
    required AuditLogDataSource auditLogDataSource,
  })  : _remoteDataSource = remoteDataSource,
        _auditLogDataSource = auditLogDataSource;

  final UserRemoteDataSource _remoteDataSource;
  final AuditLogDataSource _auditLogDataSource;

  @override
  Future<UserModel> getUserById(String userId) async {
    return await _remoteDataSource.getUserById(userId);
  }

  @override
  Future<UserModel> getUserByUsername(String username) async {
    return await _remoteDataSource.getUserByUsername(username);
  }

  @override
  Future<List<UserModel>> getAllUsers() async {
    return await _remoteDataSource.getAllUsers();
  }

  @override
  Future<List<UserModel>> getUsersByRole(UserRole role) async {
    return await _remoteDataSource.getUsersByRole(role);
  }

  @override
  Future<UserModel> createUser(
    UserModel user,
    String password,
    String performedBy,
  ) async {
    try {
      final createdUser = await _remoteDataSource.createUser(user, password);

      await _auditLogDataSource.logAction(
        action: AuditAction.userCreated,
        performedBy: performedBy,
        performedFor: createdUser.id,
        metadata: {
          'username': createdUser.username,
          'role': createdUser.role.name,
          'email': createdUser.email,
        },
        description: 'User created: ${createdUser.username}',
      );

      AppLogger.info('User created: ${createdUser.username}');

      return createdUser;
    } catch (e, stackTrace) {
      AppLogger.error('Create user error', e, stackTrace);
      rethrow;
    }
  }

  @override
  Future<UserModel> updateUser(UserModel user, String performedBy) async {
    try {
      final updatedUser = await _remoteDataSource.updateUser(user);

      await _auditLogDataSource.logAction(
        action: AuditAction.userUpdated,
        performedBy: performedBy,
        performedFor: updatedUser.id,
        metadata: {
          'username': updatedUser.username,
          'role': updatedUser.role.name,
        },
        description: 'User updated: ${updatedUser.username}',
      );

      AppLogger.info('User updated: ${updatedUser.username}');

      return updatedUser;
    } catch (e, stackTrace) {
      AppLogger.error('Update user error', e, stackTrace);
      rethrow;
    }
  }

  @override
  Future<void> deleteUser(String userId, String performedBy) async {
    try {
      final user = await _remoteDataSource.getUserById(userId);
      
      await _remoteDataSource.deleteUser(userId);

      await _auditLogDataSource.logAction(
        action: AuditAction.userDeleted,
        performedBy: performedBy,
        performedFor: userId,
        metadata: {
          'username': user.username,
        },
        description: 'User deleted: ${user.username}',
      );

      AppLogger.info('User deleted: ${user.username}');
    } catch (e, stackTrace) {
      AppLogger.error('Delete user error', e, stackTrace);
      rethrow;
    }
  }

  @override
  Future<void> activateUser(String userId, String performedBy) async {
    try {
      final user = await _remoteDataSource.getUserById(userId);
      
      await _remoteDataSource.activateUser(userId);

      await _auditLogDataSource.logAction(
        action: AuditAction.userActivated,
        performedBy: performedBy,
        performedFor: userId,
        metadata: {
          'username': user.username,
        },
        description: 'User activated: ${user.username}',
      );

      AppLogger.info('User activated: ${user.username}');
    } catch (e, stackTrace) {
      AppLogger.error('Activate user error', e, stackTrace);
      rethrow;
    }
  }

  @override
  Future<void> deactivateUser(String userId, String performedBy) async {
    try {
      final user = await _remoteDataSource.getUserById(userId);
      
      await _remoteDataSource.deactivateUser(userId);

      await _auditLogDataSource.logAction(
        action: AuditAction.userDeactivated,
        performedBy: performedBy,
        performedFor: userId,
        metadata: {
          'username': user.username,
        },
        description: 'User deactivated: ${user.username}',
      );

      AppLogger.info('User deactivated: ${user.username}');
    } catch (e, stackTrace) {
      AppLogger.error('Deactivate user error', e, stackTrace);
      rethrow;
    }
  }

  @override
  Future<String> resetPassword(String userId, String performedBy) async {
    try {
      final user = await _remoteDataSource.getUserById(userId);
      
      final tempPassword = await _remoteDataSource.resetPassword(userId, _generateTempPassword());

      await _auditLogDataSource.logAction(
        action: AuditAction.passwordReset,
        performedBy: performedBy,
        performedFor: userId,
        metadata: {
          'username': user.username,
        },
        description: 'Password reset for user: ${user.username}',
      );

      AppLogger.info('Password reset for user: ${user.username}');

      return tempPassword;
    } catch (e, stackTrace) {
      AppLogger.error('Reset password error', e, stackTrace);
      rethrow;
    }
  }

  @override
  Future<bool> isUsernameAvailable(String username) async {
    return await _remoteDataSource.isUsernameAvailable(username);
  }

  String _generateTempPassword() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#\$%^&*';
    final random = DateTime.now().millisecondsSinceEpoch;
    return List.generate(12, (index) => chars[(random + index) % chars.length]).join();
  }
}
