import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:f2c/core/constants/app_constants.dart';
import 'package:f2c/core/shared/logger/app_logger.dart';
import 'package:f2c/features/authentication/models/session_model.dart';
import 'package:f2c/features/authentication/models/user_role.dart';

abstract class SessionLocalDataSource {
  Future<void> saveSession(SessionModel session);
  Future<SessionModel?> getSession();
  Future<void> clearSession();
  Future<bool> hasActiveSession();
  Future<void> saveLastUsername(String username);
  Future<String?> getLastUsername();
  Future<void> clearLastUsername();
}

class SessionLocalDataSourceImpl implements SessionLocalDataSource {
  SessionLocalDataSourceImpl({
    required SharedPreferences sharedPreferences,
  }) : _sharedPreferences = sharedPreferences;

  final SharedPreferences _sharedPreferences;

  @override
  Future<void> saveSession(SessionModel session) async {
    try {
      await _sharedPreferences.setBool(StorageKeys.isLoggedIn, true);
      await _sharedPreferences.setString(StorageKeys.userId, session.uid);
      await _sharedPreferences.setString(StorageKeys.username, session.username);
      await _sharedPreferences.setString(StorageKeys.userRole, session.role.name);
      
      if (session.branchId != null) {
        await _sharedPreferences.setString(StorageKeys.branchId, session.branchId!);
      }
      
      if (session.hubId != null) {
        await _sharedPreferences.setString(StorageKeys.hubId, session.hubId!);
      }
      
      await _sharedPreferences.setString(
        StorageKeys.loginTime,
        session.loginTime.toIso8601String(),
      );
      await _sharedPreferences.setString(StorageKeys.authToken, session.token);
      await _sharedPreferences.setBool(StorageKeys.rememberMe, session.rememberMe);

      AppLogger.info('Session saved successfully');
    } catch (e, stackTrace) {
      AppLogger.error('Failed to save session', e, stackTrace);
      rethrow;
    }
  }

  @override
  Future<SessionModel?> getSession() async {
    try {
      final isLoggedIn = _sharedPreferences.getBool(StorageKeys.isLoggedIn) ?? false;
      
      if (!isLoggedIn) {
        return null;
      }

      final uid = _sharedPreferences.getString(StorageKeys.userId);
      final username = _sharedPreferences.getString(StorageKeys.username);
      final roleString = _sharedPreferences.getString(StorageKeys.userRole);
      final loginTimeString = _sharedPreferences.getString(StorageKeys.loginTime);
      final token = _sharedPreferences.getString(StorageKeys.authToken);
      final rememberMe = _sharedPreferences.getBool(StorageKeys.rememberMe) ?? false;

      if (uid == null || username == null || roleString == null || 
          loginTimeString == null || token == null) {
        return null;
      }

      final branchId = _sharedPreferences.getString(StorageKeys.branchId);
      final hubId = _sharedPreferences.getString(StorageKeys.hubId);

      return SessionModel(
        uid: uid,
        username: username,
        role: _parseUserRole(roleString),
        branchId: branchId,
        hubId: hubId,
        loginTime: DateTime.parse(loginTimeString),
        token: token,
        rememberMe: rememberMe,
      );
    } catch (e, stackTrace) {
      AppLogger.error('Failed to get session', e, stackTrace);
      return null;
    }
  }

  @override
  Future<void> clearSession() async {
    try {
      await _sharedPreferences.remove(StorageKeys.isLoggedIn);
      await _sharedPreferences.remove(StorageKeys.userId);
      await _sharedPreferences.remove(StorageKeys.username);
      await _sharedPreferences.remove(StorageKeys.userRole);
      await _sharedPreferences.remove(StorageKeys.branchId);
      await _sharedPreferences.remove(StorageKeys.hubId);
      await _sharedPreferences.remove(StorageKeys.loginTime);
      await _sharedPreferences.remove(StorageKeys.authToken);
      await _sharedPreferences.remove(StorageKeys.rememberMe);

      AppLogger.info('Session cleared successfully');
    } catch (e, stackTrace) {
      AppLogger.error('Failed to clear session', e, stackTrace);
      rethrow;
    }
  }

  @override
  Future<bool> hasActiveSession() async {
    return _sharedPreferences.getBool(StorageKeys.isLoggedIn) ?? false;
  }

  @override
  Future<void> saveLastUsername(String username) async {
    await _sharedPreferences.setString(StorageKeys.lastUsername, username);
  }

  @override
  Future<String?> getLastUsername() async {
    return _sharedPreferences.getString(StorageKeys.lastUsername);
  }

  @override
  Future<void> clearLastUsername() async {
    await _sharedPreferences.remove(StorageKeys.lastUsername);
  }

  UserRole _parseUserRole(String roleString) {
    return UserRole.values.firstWhere(
      (role) => role.name == roleString,
      orElse: () => UserRole.customer,
    );
  }
}
